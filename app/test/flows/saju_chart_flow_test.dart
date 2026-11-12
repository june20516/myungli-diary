import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/depth/weighing_note.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/depth/presentation/evidence_sheet.dart';
import 'package:myungli_diary/features/depth/presentation/explain_sheet.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/me/presentation/natal_card.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/chart_network.dart';
import '../support/depth_link_finders.dart';
import '../support/my_saju_finders.dart';
import '../support/onboarding_steps.dart';
import '../support/sheet_close.dart';
import '../support/test_today.dart';

final _ko = AppLocalizationsKo();

final Finder _chart = find.byKey(const ValueKey(ScreenIds.sajuChart));

/// 대운·세운 표 [cell] 안에서 글자가 [label]인 용어 칩. 같은 글자가 여럿이면 위의 것입니다.
Finder _luckChip(Key cell, LuckLabel label) => find
    .descendant(
      of: find.byKey(cell),
      matching: find.byWidgetPredicate(
        (widget) => widget is TermToken && widget.label == label.text,
      ),
    )
    .first;

Finder _inChart(Finder matching) =>
    find.descendant(of: _chart, matching: matching);

/// 만세력 표 안 띠 표.
BandTable _band(ManseTable manse) => manse.table;

/// 띠 표 안.
Finder _inBand(Finder matching) =>
    find.descendant(of: _inChart(find.byType(BandTable)), matching: matching);

/// 용신 판정 근거 줄.
final Finder _yongsinBasis = _inChart(
  find.byWidgetPredicate(
    (widget) =>
        widget is SentenceBlock &&
        widget.slotId == SlotIds.sajuChartYongsinBasis,
  ),
);

/// 시간 모름 안내 배너.
final Finder _timeUnknownBanner = _inChart(
  find.byWidgetPredicate(
    (widget) =>
        widget is NoticeBanner &&
        widget.variant == NoticeBannerVariant.timeUnknown,
  ),
);

final Finder _evidenceSheet = find.byKey(const Key(ScreenIds.evidenceSheet));

Finder _inEvidence(Finder matching) =>
    find.descendant(of: _evidenceSheet, matching: matching);

/// 잠긴 용신 판정 근거의 "열기"를 화면에 들인 뒤 누릅니다.
Future<void> _tapYongsinOpen(WidgetTester tester) async {
  final open = _inChart(
    find.bySemanticsIdentifier(SlotIds.sajuChartYongsinOpen),
  );
  await tester.ensureVisible(open);
  await tester.pumpAndSettle();
  await tester.tap(open);
}

/// 내용이 그려졌거나 오류가 보일 때까지 기다립니다.
Future<void> _settleChart(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () =>
        _inChart(find.byType(SajuPillars)).evaluate().isNotEmpty ||
        _inChart(find.byType(ErrorState)).evaluate().isNotEmpty,
  );
  await settleWithIo(tester);
}

/// [scenario]로 앱을 띄우고 나 탭 → 나의 사주 → "근거 보기"로 사주 표를 엽니다.
Future<ProviderContainer> _openFromMySaju(
  WidgetTester tester, {
  String scenario = 'member',
  List<Override> overrides = const [],
  Interceptor? network,
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    overrides: overrides,
  );
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  await tester.tap(find.byKey(const ValueKey('tab-bar.tab.3')));
  await pumpUntilScreen(tester, ScreenIds.mySaju);
  await settleWithIo(tester);
  final link = mySajuChartLink(
    of: find.byKey(const ValueKey(ScreenIds.mySaju)),
  );
  await tester.scrollUntilVisible(
    link,
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey(ScreenIds.mySaju)),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(link);
  await pumpUntilScreen(tester, ScreenIds.sajuChart);
  await _settleChart(tester);
  return container;
}

/// [network]를 끼운 뒤 오늘 화면에서 사주 표로 바로 갑니다(나의 사주가 먼저 받지 않게).
Future<ProviderContainer> _pushChart(
  WidgetTester tester,
  ChartNetwork network, {
  bool settle = true,
}) async {
  final container = await pumpApp(tester, scenario: 'member');
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, network);
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.sajuChart)),
  );
  await pumpUntilScreen(tester, ScreenIds.sajuChart);
  if (settle) await _settleChart(tester);
  return container;
}

/// "만세력·대운" 탭을 누릅니다.
Future<void> _openLuckTab(WidgetTester tester) async {
  await tester.tap(_inChart(find.text(_ko.sajuChartTabLuck)));
  await tester.pumpAndSettle();
}

/// 표 칸 용어 [term]을 눌러 풀이 시트 → "근거 보기"로 근거 시트를 엽니다.
Future<void> _openPersonal(WidgetTester tester, Finder term) async {
  // 사주 표의 세로 목록(첫 Scrollable)을 내려 칸이 화면에 들어오게 합니다.
  await tester.scrollUntilVisible(
    term,
    120,
    scrollable: _inChart(find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(term);
  await settleWithIo(tester);
  final explain = find.byKey(const Key(ScreenIds.explainSheet));
  expect(explain, findsOneWidget);
  await tester.tap(depthLinkTarget(of: explain));
  await settleWithIo(tester);
  expect(_evidenceSheet, findsOneWidget);
}

/// 열린 근거 시트가 받은 원국 개인 해석의 자리.
PersonalReadingKey? _personalKey(WidgetTester tester) =>
    tester.widget<EvidenceSheet>(find.byType(EvidenceSheet)).personal;

/// 근거 시트의 "내 사주에서는" 문장에 [text]가 있는지.
Finder _personalText(String text) =>
    _inEvidence(find.textContaining(text, findRichText: true));

/// member 사전의 범주별 이름.
Map<String, Map<String, String>> _memberGlossaryValues() {
  final json = jsonDecode(
    File('fixtures/member/getGlossary.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final body = json['body'] as Map<String, dynamic>;
  return {
    for (final entry in (body['values'] as Map<String, dynamic>).entries)
      entry.key: Map<String, String>.from(entry.value as Map),
  };
}

/// member 사전의 용어 뜻(`Glossary.meanings`). 뜻이 없으면 표 칸이 근거 시트를 바로 열므로
/// (A130) 풀이 시트를 거치는 사례는 뜻도 함께 둡니다.
Map<String, RenderedText> _memberGlossaryMeanings() {
  final json = jsonDecode(
    File('fixtures/member/getGlossary.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final body = json['body'] as Map<String, dynamic>;
  return {
    for (final entry in (body['meanings'] as Map<String, dynamic>).entries)
      entry.key: RenderedText.fromJson(entry.value as Map<String, dynamic>),
  };
}

/// 12운성·신살 이름을 일부만 둔 사전(이름이 없는 값은 한자 글자로 대신함, A65).
Future<GlossaryNames> _glossaryWithStages() async {
  final values = _memberGlossaryValues();
  values['twelve_stage'] = const {'yang': '양', 'mokyok': '목욕'};
  values['shinsal'] = const {'hwagae': '화개'};
  return GlossaryNames(values, meanings: _memberGlossaryMeanings());
}

/// 12운성·신살 범주가 없는 사전(server 시드가 이름을 넣기 전을 흉내 냄).
Future<GlossaryNames> _glossaryWithoutStages() async {
  final values = _memberGlossaryValues()
    ..remove('twelve_stage')
    ..remove('shinsal');
  return GlossaryNames(values, meanings: _memberGlossaryMeanings());
}

/// 열린 나의 사주 응답에서 용신 판정 근거 문장(`yongsin.basis`)을 뺍니다(계약상 선택값).
final class _DropUnlockedBasis extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/chart' &&
        data is Map &&
        data['evidenceAccess'] == 'unlocked') {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      body['yongsin'] = Map<String, Object?>.of(
        (body['yongsin']! as Map).cast<String, Object?>(),
      )..remove('basis');
      response.data = body;
    }
    handler.next(response);
  }
}

/// 받은 나의 사주에서 원국 개인 해석을 뺍니다(원고가 없는 자리를 흉내 냄).
final class _DropPersonal extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/chart' && data is Map) {
      response.data = Map<String, Object?>.of(data.cast<String, Object?>())
        ..remove('personalReadings');
    }
    handler.next(response);
  }
}

/// 받은 나의 사주의 일지 자리에 이 app이 모르는 신살(열린 enum, A66)을 더합니다.
final class _AddUnknownShinsal extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/chart' && data is Map) {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      body['shinsal'] = [
        ...body['shinsal']! as List<Object?>,
        {
          'kind': 'added_after_freeze',
          'position': 'day_branch',
          'positions': ['day_branch'],
        },
      ];
      response.data = body;
    }
    handler.next(response);
  }
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('제목, 두 탭(원국부터), 원국표·오행 분포·잠긴 용신 판정 근거', (tester) async {
    covers(const Covers(decisions: ['D16', 'D18']));
    await _openFromMySaju(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.sajuChartBarTitle,
      _ko.sajuChartBarTitle,
    );

    final tabs = tester.widget<Segmented<Object>>(
      _inChart(find.byWidgetPredicate((w) => w is Segmented)),
    );
    expect(tabs.items.map((item) => item.label), [
      _ko.sajuChartTabNatal,
      _ko.sajuChartTabLuck,
    ]);

    // 원국표: 시·일·월·연, 일주 천간은 庚(일간), 연주 천간 위 십성은 비견입니다.
    final pillars = tester.widget<SajuPillars>(
      _inChart(find.byType(SajuPillars)),
    );
    expect(pillars.day.stem?.hanja, '庚');
    expect(pillars.hour.stem?.hanja, '癸');
    expect(pillars.year.stemLabel, isA<TermToken>());
    expect((pillars.year.stemLabel! as TermToken).label, '비견');
    // 일간 칩은 용어 role.day_master를 엽니다(F-019). member 사전에 그 이름(일간)이 있어
    // 누를 수 있는 용어 칩입니다.
    expect(pillars.day.stemLabel, isA<TermToken>());
    expect((pillars.day.stemLabel! as TermToken).label, '일간');
    expect(pillars.tableLabel, _ko.sajuPillarsTableLabel);

    // 오행 분포: 목·화·토·금·수, 값은 소수 한 자리.
    final bar = tester.widget<OhaengBar>(_inChart(find.byType(OhaengBar)));
    final counts = {for (final item in bar.items) item.element: item.count};
    expect(counts[FiveElement.wood], '0.6');
    expect(counts[FiveElement.fire], '3.3');
    expect(counts[FiveElement.metal], '2.9');
    expect(bar.semanticLabel, startsWith('목 0.6, 화 3.3'));

    // 잠긴 용신 판정 근거: 이름 + 흐린 두 줄 + 자물쇠 "열기".
    expect(_inChart(find.text(_ko.sajuChartYongsinTitle)), findsOneWidget);
    final basis = tester.widget<SentenceBlock>(
      _inChart(find.byType(SentenceBlock)),
    );
    expect(basis.locked, isTrue);
    expect(
      _inChart(find.bySemanticsIdentifier(SlotIds.sajuChartYongsinOpen)),
      findsOneWidget,
    );
    // 만세력 표는 다른 탭입니다.
    expect(_inChart(find.byType(ManseTable)), findsNothing);
  });

  testWidgets('만세력·대운 탭: 만세력 표와 대운 표(지금 대운·올해 세운), 다시 열면 원국부터', (tester) async {
    final container = await _openFromMySaju(tester);
    await _openLuckTab(tester);

    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    final band = _band(manse);
    expect(band.columns[3].hiddenStems.map((stem) => stem.hanja), ['丁', '己']);
    expect(manse.basisGlyph, '庚');
    expect(band.tableLabel, _ko.manseTableLabel);

    final daeun = tester.widget<DaeunTable>(_inChart(find.byType(DaeunTable)));
    expect(daeun.daeun.map((pillar) => pillar.age).take(4), [4, 14, 24, 34]);
    // 1990년생: 34세 대운이 2023년에 시작해 2026년(올해)의 지금 대운입니다.
    expect(daeun.currentIndex, 3);
    expect(daeun.daeun[3].startYear, 2023);
    expect(daeun.thisYear, 2026);
    expect(daeun.seun.map((year) => year.year), [
      for (var year = 2023; year <= 2032; year++) year,
    ]);
    expect(daeun.nowLabel, _ko.daeunTagNow);
    expect(daeun.thisYearLabel, _ko.seunTagThisYear);
    expect(_inChart(find.byType(SajuPillars)), findsNothing);

    // 화면을 떠났다 오면 탭을 기억하지 않습니다(A57).
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    final link = mySajuChartLink(
      of: find.byKey(const ValueKey(ScreenIds.mySaju)),
    );
    await tester.tap(link);
    await pumpUntilScreen(tester, ScreenIds.sajuChart);
    await _settleChart(tester);
    expect(_inChart(find.byType(SajuPillars)), findsOneWidget);
  });

  testWidgets('잠긴 용신 판정 근거의 "열기" → 근거 시트(잠김)', (tester) async {
    covers(
      const Covers(exits: ['saju-chart>evidence-sheet'], decisions: ['D60']),
    );
    await _openFromMySaju(tester);
    await _tapYongsinOpen(tester);
    await settleWithIo(tester);
    expect(_evidenceSheet, findsOneWidget);
    expect(_inEvidence(find.byType(EvidenceLockPanel)), findsOneWidget);
    // 용신 판정 근거는 문장 자체가 근거라 원전 구역이 없고, 판정 근거 구역은 사주 표와 같은
    // 앞부분으로 잠깁니다(#931, A129).
    final body = tester.widget<EvidenceSheetBody>(
      _inEvidence(find.byType(EvidenceSheetBody)),
    );
    expect(body.showSource, isFalse);
    expect(body.basisLead, isNotNull);
    expect(
      _inEvidence(find.text(_ko.evidenceSheetSectionSource)),
      findsNothing,
    );
  });

  testWidgets('evidence-unlocked: 용신 판정 근거 속 용어 시트에는 근거 보기가 없습니다(#931)', (
    tester,
  ) async {
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    final term = find.descendant(
      of: _yongsinBasis,
      matching: find.byType(TermToken),
    );
    expect(term, findsWidgets);
    await tester.ensureVisible(term.first);
    await tester.pumpAndSettle();
    await tester.tap(term.first);
    await settleWithIo(tester);
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(explain, findsOneWidget);
    expect(
      find.descendant(of: explain, matching: find.byType(DepthLink)),
      findsNothing,
    );
  });

  testWidgets('reward-unlock: 광고로 잠금을 풀면 차트를 다시 받아 용신 판정 근거가 열리고 오늘도 열립니다', (
    tester,
  ) async {
    final container = await _openFromMySaju(
      tester,
      scenario: 'reward-unlock',
      overrides: [
        rewardPollTimingProvider.overrideWithValue((
          interval: const Duration(milliseconds: 100),
          // 열림을 기대하므로 마감은 깁니다(마감이 응답보다 먼저 지나지 않게).
          timeout: const Duration(minutes: 10),
        )),
      ],
    );
    expect(
      container.read(chartControllerProvider).value?.evidenceAccess,
      EvidenceAccess.locked,
    );
    await _tapYongsinOpen(tester);
    final unlock = evidenceUnlockControllerProvider(
      const ChartEvidenceSubject(),
    );
    await pumpUntil(
      tester,
      () => container.exists(unlock) && container.read(unlock).adReady,
    );

    await tester.tap(_inEvidence(find.byKey(EvidenceLockPanel.ctaKey)));
    await pumpUntil(
      tester,
      () =>
          container.read(chartControllerProvider).value?.evidenceAccess ==
              EvidenceAccess.unlocked &&
          container.read(dailyControllerProvider).value?.daily.evidenceAccess ==
              EvidenceAccess.unlocked,
      allowOngoing: true,
    );
    await settleWithIo(tester);
    expect(_inEvidence(find.byType(EvidenceLockPanel)), findsNothing);
    // 열린 근거 시트는 비지 않고 용신 판정 근거 문장을 판정 근거로 보입니다(#931).
    expect(
      _inEvidence(find.text(_ko.evidenceSheetSectionBasis)),
      findsOneWidget,
    );
    expect(
      _inEvidence(find.textContaining('정했어요', findRichText: true)),
      findsOneWidget,
    );
    expect(
      _inEvidence(find.text(_ko.evidenceSheetSectionSource)),
      findsNothing,
    );

    // 시트를 닫으면 사주 표의 용신 판정 근거가 문장으로 보입니다.
    await closeSheet(tester, _evidenceSheet);
    final basis = tester.widget<SentenceBlock>(_yongsinBasis);
    expect(basis.locked, isFalse);
    expect(
      _inChart(find.textContaining('정했어요', findRichText: true)),
      findsOneWidget,
    );
  });

  testWidgets('reward-unlock: 열렸는데 용신 판정 문장이 없으면 빈 근거 시트를 남기지 않고 닫습니다(#931)', (
    tester,
  ) async {
    final container = await _openFromMySaju(
      tester,
      scenario: 'reward-unlock',
      network: _DropUnlockedBasis(),
      overrides: [
        rewardPollTimingProvider.overrideWithValue((
          interval: const Duration(milliseconds: 100),
          timeout: const Duration(minutes: 10),
        )),
      ],
    );
    await _tapYongsinOpen(tester);
    final unlock = evidenceUnlockControllerProvider(
      const ChartEvidenceSubject(),
    );
    await pumpUntil(
      tester,
      () => container.exists(unlock) && container.read(unlock).adReady,
    );
    await tester.tap(_inEvidence(find.byKey(EvidenceLockPanel.ctaKey)));
    await pumpUntil(
      tester,
      () =>
          container.read(chartControllerProvider).value?.evidenceAccess ==
          EvidenceAccess.unlocked,
      allowOngoing: true,
    );
    await settleWithIo(tester);
    expect(_evidenceSheet, findsNothing);
  });

  testWidgets('evidence-unlocked: 십성 용어 → 풀이 시트 → 근거 보기 → 내 사주에서는(개인 해석)', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['saju-chart>explain-sheet', 'explain-sheet>evidence-sheet'],
      ),
    );
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    final basis = tester.widget<SentenceBlock>(_yongsinBasis);
    expect(basis.locked, isFalse);

    await tester.tap(_inChart(find.widgetWithText(TermToken, '비견')).first);
    await settleWithIo(tester);
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(explain, findsOneWidget);
    await tester.tap(depthLinkTarget(of: explain));
    await settleWithIo(tester);

    expect(_evidenceSheet, findsOneWidget);
    expect(
      _inEvidence(find.text(_ko.evidenceSheetSectionPersonal)),
      findsOneWidget,
    );
    expect(
      _inEvidence(find.textContaining('내 사주에서 이 십성 자리는', findRichText: true)),
      findsOneWidget,
    );
    // 표 칸의 근거 시트에는 용신 판정 근거가 섞이지 않습니다.
    expect(_inEvidence(find.text(_ko.evidenceSheetSectionBasis)), findsNothing);
  });

  testWidgets('evidence-unlocked: 일간 → 용어 "일간" 풀이(F-019) → 근거 보기 → 일간 개인 해석', (
    tester,
  ) async {
    await _openFromMySaju(
      tester,
      scenario: 'evidence-unlocked',
      overrides: [
        glossaryProvider.overrideWith((ref) async {
          final names = await _glossaryWithStages();
          return GlossaryNames({
            ...names.values,
            'role': {...?names.values['role'], 'day_master': '일간'},
          }, meanings: names.meanings);
        }),
      ],
    );
    final pillars = tester.widget<SajuPillars>(
      _inChart(find.byType(SajuPillars)),
    );
    await _openPersonal(tester, find.byWidget(pillars.day.stemLabel!));
    // 풀이 시트는 천간(庚)이 아니라 용어 "일간"입니다(F-019).
    expect(
      (tester.widget<ExplainSheet>(find.byType(ExplainSheet)).content
              as ExplainTerm)
          .termId,
      dayMasterTermId,
    );
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindDayMaster,
        position: Position.dayStem,
      ),
    );
    expect(_personalText('이 일간 자리는'), findsOneWidget);
  });

  testWidgets('evidence-unlocked: 지장간 십성 → 지장간 개인 해석(지지 자리·순서)', (
    tester,
  ) async {
    await _openFromMySaju(
      tester,
      scenario: 'evidence-unlocked',
      overrides: [
        glossaryProvider.overrideWith((ref) => _glossaryWithoutStages()),
      ],
    );
    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    // 연지 午의 지장간 丁(정관)·己(정인). 둘째(己)의 십성을 누릅니다.
    final label = _band(manse).columns[3].hiddenStems[1].tenGod;
    expect(label?.text, '정인');
    // 사전에 12운성·신살 이름이 없으면 칸을 비웁니다(A65).
    expect(_band(manse).columns[3].twelveStage, isNull);

    // 연주 열은 가장 오른쪽 열이라 같은 십성 가운데 가장 오른쪽 칩입니다.
    final chips = _inBand(find.widgetWithText(TermToken, '정인'));
    final rightmost = [
      for (var i = 0; i < chips.evaluate().length; i++) chips.at(i),
    ]..sort((a, b) => tester.getCenter(b).dx.compareTo(tester.getCenter(a).dx));
    await _openPersonal(tester, rightmost.first);
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindHiddenTenGod,
        position: Position.yearBranch,
        index: 1,
      ),
    );
    expect(_personalText('이 지장간 자리는'), findsOneWidget);
  });

  testWidgets('evidence-unlocked: 대운 천간 십성 → 대운 개인 해석(대운 순서)', (tester) async {
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    await _openLuckTab(tester);
    final daeun = tester.widget<DaeunTable>(_inChart(find.byType(DaeunTable)));
    expect(daeun.daeun[3].branchLabel?.onTap, isNotNull);
    await _openPersonal(
      tester,
      _luckChip(DaeunTable.daeunKey(3), daeun.daeun[3].stemLabel!),
    );
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindDaeunStemTenGod,
        index: 3,
      ),
    );
    expect(_personalText('이 대운 천간 자리는'), findsOneWidget);
  });

  testWidgets('evidence-unlocked: 세운 십성 → 세운 개인 해석(세운 순서)', (tester) async {
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    await _openLuckTab(tester);
    final daeun = tester.widget<DaeunTable>(_inChart(find.byType(DaeunTable)));
    await _openPersonal(
      tester,
      _luckChip(DaeunTable.seunKey(daeun.seun[3].year), daeun.seun[3].label!),
    );
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindSeunTenGod,
        index: 3,
      ),
    );
    expect(_personalText('이 세운 자리는'), findsOneWidget);
  });

  testWidgets('대운 12운성은 사전 이름이 있으면 칩, 누르면 대운 12운성 개인 해석(V49)', (tester) async {
    await _openFromMySaju(
      tester,
      scenario: 'evidence-unlocked',
      overrides: [
        glossaryProvider.overrideWith((ref) => _glossaryWithStages()),
      ],
    );
    await _openLuckTab(tester);
    final daeun = tester.widget<DaeunTable>(_inChart(find.byType(DaeunTable)));
    // 사전 대역은 12운성 중 '양'(첫 대운)만 이름이 있고, 나머지는 한자 글자입니다(A65).
    final first = daeun.daeun[0].stageLabel!;
    expect(first.text, '양');
    expect(first.onTap, isNotNull);
    expect(daeun.daeun[1].stageLabel?.onTap, isNull);

    await tester.ensureVisible(_luckChip(DaeunTable.daeunKey(0), first));
    await tester.pumpAndSettle();
    await _openPersonal(tester, _luckChip(DaeunTable.daeunKey(0), first));
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindDaeunTwelveStage,
        index: 0,
      ),
    );
    expect(_personalText('이 대운 12운성 자리는'), findsOneWidget);
  });

  testWidgets('사전에 12운성·신살 이름이 있으면 그 칸도 개인 해석으로 이어집니다', (tester) async {
    await _openFromMySaju(
      tester,
      scenario: 'evidence-unlocked',
      overrides: [
        glossaryProvider.overrideWith((ref) => _glossaryWithStages()),
      ],
    );
    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    final dayColumn = _band(manse).columns[1];
    expect(dayColumn.twelveStage?.onTap, isNotNull);
    expect(dayColumn.shinsal.single.text, '화개');

    await _openPersonal(
      tester,
      _inBand(find.widgetWithText(TermToken, dayColumn.twelveStage!.text)),
    );
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindTwelveStage,
        position: Position.dayBranch,
      ),
    );
    expect(_personalText('이 12운성 자리는'), findsOneWidget);

    // 근거 시트와 풀이 시트를 닫고 신살 칸을 누릅니다.
    await closeSheet(tester, _evidenceSheet);
    await closeSheet(tester, find.byKey(const Key(ScreenIds.explainSheet)));
    await _openPersonal(tester, _inBand(find.widgetWithText(TermToken, '화개')));
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindShinsal,
        position: Position.dayBranch,
        shinsal: ShinsalKind.hwagae,
      ),
    );
    // 신살 개인 해석은 writing 원고(`personal.shinsal.hwagae`)를 렌더한 문장입니다.
    expect(_personalText('혼자 깊이 파고드는'), findsOneWidget);
  });

  testWidgets('D124 ① 신살 띠: 걸친 기둥마다, 천간 자리 → 일주 신살 → 지지 자리로 모두 쌓습니다', (
    tester,
  ) async {
    covers(const Covers(decisions: ['D124']));
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    List<String> names(int column) => [
      for (final label in _band(manse).columns[column].shinsal) label.text,
    ];
    // fixture는 엔진 값입니다. 월덕은 연간과 일간 두 자리, 괴강과 십악대패는 일간과 일지에 걸친
    // 일주 신살(대표 일지)입니다. 이름은 사전(원고)에서 옵니다.
    expect(names(0), ['천을귀인']);
    expect(names(1), ['월덕귀인', '괴강', '십악대패', '화개', '과숙']);
    expect(names(2), ['천덕귀인', '암록']);
    expect(names(3), ['월덕귀인']);

    // 일주 신살은 일주 칸 하나뿐이고, 누르면 대표 자리(일지)의 원국 개인 해석입니다.
    expect(_inBand(find.widgetWithText(TermToken, '괴강')), findsOneWidget);
    await _openPersonal(
      tester,
      _inBand(find.widgetWithText(TermToken, '괴강')).first,
    );
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindShinsal,
        position: Position.dayBranch,
        shinsal: ShinsalKind.goegang,
      ),
    );
    expect(_personalText('괴강이 있어 기운이 세고'), findsOneWidget);
    await closeSheet(tester, _evidenceSheet);
    // 흉 신살이 아닌 괴강의 풀이 시트에는 마무리 한 줄이 없습니다.
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(
      find.descendant(of: explain, matching: find.byKey(WeighingNote.boxKey)),
      findsNothing,
    );
    await closeSheet(tester, explain);

    // 같은 신살이 두 기둥에 있으면 칸마다 그 자리의 해석입니다(일간의 월덕).
    expect(_inBand(find.widgetWithText(TermToken, '월덕귀인')), findsNWidgets(2));
    await _openPersonal(
      tester,
      _inBand(find.widgetWithText(TermToken, '월덕귀인')).first,
    );
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindShinsal,
        position: Position.dayStem,
        shinsal: ShinsalKind.woldeok,
      ),
    );
    expect(_personalText('태어난 날의 천간에 월덕귀인'), findsOneWidget);
  });

  testWidgets('D124 ① 나의 사주 → 사주 표: 띠의 모든 신살(새 신살 포함)이 그 자리 원국 개인 해석으로 이어집니다', (
    tester,
  ) async {
    covers(const Covers(decisions: ['D124']));
    // fixture의 원국 개인 해석 가운데 신살 항목(server가 원고로 렌더한 문장).
    final body =
        (jsonDecode(
              File('fixtures/evidence-unlocked/getChart.json')
                  .readAsStringSync(),
            ) as Map<String, dynamic>)['body']
            as Map<String, dynamic>;
    final expected = <PersonalReadingKey, String>{
      for (final reading in [
        for (final json in body['personalReadings'] as List<dynamic>)
          PersonalReading.fromJson(json as Map<String, dynamic>),
      ])
        if (reading.kind == PersonalReadingKindEnum.PersonalReadingKindShinsal)
          PersonalReadingKey(
            kind: reading.kind,
            position: reading.position,
            shinsal: reading.shinsal,
          ): reading.text.segments
              .map((segment) => segment.text)
              .join(),
    };
    // 이 task에서 더한 신살(천덕, 월덕, 과숙, 괴강, 십악대패, 암록)이 fixture에 있습니다.
    expect(
      {for (final key in expected.keys) key.shinsal},
      containsAll(<ShinsalKind>{
        ShinsalKind.cheondeok,
        ShinsalKind.woldeok,
        ShinsalKind.gwasuk,
        ShinsalKind.goegang,
        ShinsalKind.sipakDaepae,
        ShinsalKind.amrok,
      }),
    );

    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    final seen = <PersonalReadingKey>{};
    final shown = <String, int>{};
    for (final column in _band(manse).columns) {
      for (final label in column.shinsal) {
        // 같은 이름 칩이 여러 칸에 있으면 띠 순서(시, 일, 월, 연)대로 차례로 누릅니다.
        final index = shown.update(label.text, (n) => n + 1, ifAbsent: () => 0);
        await _openPersonal(
          tester,
          _inBand(find.widgetWithText(TermToken, label.text)).at(index),
        );
        final key = _personalKey(tester)!;
        expect(expected, contains(key), reason: label.text);
        // 근거 시트의 "내 사주에서는"이 그 항목의 원고 문장입니다(앞 스무 자로 확인).
        final text = expected[key]!;
        expect(
          _personalText(text.substring(0, 20)),
          findsOneWidget,
          reason: label.text,
        );
        seen.add(key);
        await closeSheet(tester, _evidenceSheet);
        await closeSheet(tester, find.byKey(const Key(ScreenIds.explainSheet)));
      }
    }
    // 띠의 칩이 fixture의 신살 해석을 빠짐없이 덮습니다.
    expect(seen, expected.keys.toSet());
  });

  testWidgets('D124 ⑦ 흉 신살 과숙: 풀이 시트 뜻 아래 마무리 한 줄, 근거 시트에는 없음', (tester) async {
    covers(const Covers(decisions: ['D124']));
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    await _openLuckTab(tester);
    await _openPersonal(
      tester,
      _inBand(find.widgetWithText(TermToken, '과숙')).first,
    );
    // 근거 시트(원국 개인 해석 포함)에는 두지 않습니다.
    expect(_inEvidence(find.byKey(WeighingNote.boxKey)), findsNothing);
    expect(_personalText('과숙은 가족과의 인연이'), findsOneWidget);
    await closeSheet(tester, _evidenceSheet);
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    final note = find.descendant(
      of: explain,
      matching: find.byKey(WeighingNote.boxKey),
    );
    expect(note, findsOneWidget);
    expect(
      find.descendant(of: note, matching: find.text(_ko.shinsalWeighingNote)),
      findsOneWidget,
    );
    final meaning = find.descendant(
      of: explain,
      matching: find.byKey(const Key(SlotIds.explainSheetTermMeaning)),
    );
    expect(
      tester.getRect(note).top - tester.getRect(meaning).bottom,
      moreOrLessEquals(WeighingNote.marginTop, epsilon: 0.01),
    );
  });

  testWidgets('모르는 신살(열린 enum)은 사전과 상관없이 그 칸에서 건너뜁니다', (tester) async {
    await _openFromMySaju(
      tester,
      scenario: 'evidence-unlocked',
      network: _AddUnknownShinsal(),
      overrides: [
        glossaryProvider.overrideWith((ref) async {
          final names = await _glossaryWithStages();
          // 모르는 값의 이름이 사전에 있어도 보이지 않아야 합니다.
          return GlossaryNames({
            ...names.values,
            'shinsal': const {
              'hwagae': '화개',
              'unknown_default_open_api': '모르는 신살',
            },
          }, meanings: names.meanings);
        }),
      ],
    );
    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    expect(_band(manse).columns[1].shinsal.map((label) => label.text), ['화개']);
    expect(find.text('모르는 신살'), findsNothing);
  });

  testWidgets('잠긴 표 칸 근거 시트는 내 사주에서는 구역 하나만 잠깁니다', (tester) async {
    final handle = tester.ensureSemantics();
    await _openFromMySaju(tester);
    await _openPersonal(
      tester,
      _inChart(find.widgetWithText(TermToken, '비견')).first,
    );
    expect(_inEvidence(find.byType(EvidenceLockPanel)), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '${_ko.evidenceSheetSectionPersonal}, ${_ko.evidenceSheetA11yLocked}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '${_ko.evidenceSheetSectionBasis}, ${_ko.evidenceSheetA11yLocked}',
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('열렸는데 그 자리의 해석이 없으면 빈 안내입니다', (tester) async {
    await _openFromMySaju(
      tester,
      scenario: 'evidence-unlocked',
      network: _DropPersonal(),
    );
    await _openPersonal(
      tester,
      _inChart(find.widgetWithText(TermToken, '비견')).first,
    );
    expect(
      _inEvidence(find.text(_ko.evidenceSheetSectionPersonal)),
      findsOneWidget,
    );
    expect(
      _inEvidence(find.text(_ko.evidenceSheetPersonalEmpty)),
      findsOneWidget,
    );
  });

  testWidgets('time-unknown: 시주 빈 칸과 안내', (tester) async {
    covers(const Covers(states: ['saju-chart:time-unknown']));
    await _openFromMySaju(tester, scenario: 'member-time-unknown');
    // 오프라인 배너는 숨은 채(present: false) 자리만 있어 시간 모름 배너를 골라 봅니다.
    final banner = tester.widget<NoticeBanner>(_timeUnknownBanner);
    expect(banner.variant, NoticeBannerVariant.timeUnknown);
    expect(banner.message, _ko.sajuChartTimeUnknownNotice);
    final pillars = tester.widget<SajuPillars>(
      _inChart(find.byType(SajuPillars)),
    );
    expect(pillars.hour.stem, isNull);
    expect(pillars.hour.branch, isNull);

    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    expect(_band(manse).columns[0].empty, isTrue);
    expect(_timeUnknownBanner, findsOneWidget);
  });

  testWidgets('loading: 받는 동안 skeleton, 오면 내용', (tester) async {
    covers(const Covers(states: ['saju-chart:loading']));
    final network = ChartNetwork()..hold = true;
    await _pushChart(tester, network, settle: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      _inChart(find.byKey(const ValueKey('screen-state.loading'))),
      findsOneWidget,
    );
    network.gate.complete();
    await _settleChart(tester);
    expect(_inChart(find.byType(SajuPillars)), findsOneWidget);
  });

  testWidgets('error: 받지 못하면 오류와 다시 시도', (tester) async {
    covers(const Covers(states: ['saju-chart:error']));
    final network = ChartNetwork()..fail = true;
    await _pushChart(tester, network);
    expect(_inChart(find.byType(ErrorState)), findsOneWidget);
    network.fail = false;
    await tester.tap(_inChart(find.text(_ko.actionRetry)));
    await _settleChart(tester);
    expect(_inChart(find.byType(SajuPillars)), findsOneWidget);
  });

  testWidgets('올해가 바뀌면 새 연도로 다시 받고 올해 세운 강조가 새 해를 따릅니다', (tester) async {
    final today = testTodayProvider(CalendarDate(2026, 12, 31));
    final network = ChartNetwork();
    final container = await _openFromMySaju(
      tester,
      overrides: [todayProvider.overrideWith((ref) => ref.watch(today))],
      network: network,
    );
    await _openLuckTab(tester);
    expect(
      tester.widget<DaeunTable>(_inChart(find.byType(DaeunTable))).thisYear,
      2026,
    );
    final before = network.requests;

    container.read(today.notifier).moveTo(CalendarDate(2027, 1, 1));
    await pumpUntil(tester, () => network.requests > before);
    await settleWithIo(tester);
    final daeun = tester.widget<DaeunTable>(_inChart(find.byType(DaeunTable)));
    expect(daeun.thisYear, 2027);
    expect(daeun.currentIndex, 3);
    expect(network.requests, before + 1);
  });
}
