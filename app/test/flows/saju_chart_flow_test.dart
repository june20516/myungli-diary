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
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/depth/presentation/evidence_sheet.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/chart_network.dart';
import '../support/depth_link_finders.dart';
import '../support/onboarding_steps.dart';
import '../support/test_today.dart';

final _ko = AppLocalizationsKo();

final Finder _chart = find.byKey(const ValueKey(ScreenIds.sajuChart));

Finder _inChart(Finder matching) =>
    find.descendant(of: _chart, matching: matching);

/// 용신 판정 근거 줄.
final Finder _yongsinBasis = _inChart(
  find.byWidgetPredicate(
    (widget) =>
        widget is SentenceBlock &&
        widget.slotId == SlotIds.sajuChartYongsinBasis,
  ),
);

final Finder _evidenceSheet = find.byKey(const Key(ScreenIds.evidenceSheet));

Finder _inEvidence(Finder matching) =>
    find.descendant(of: _evidenceSheet, matching: matching);

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
  final link = depthLinkTarget(
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

/// [sheet]가 담긴 시트 route를 닫습니다(누를 자리를 짐작하지 않음).
Future<void> _closeSheet(WidgetTester tester, Finder sheet) async {
  Navigator.of(tester.element(sheet)).pop();
  await tester.pumpAndSettle();
  expect(sheet, findsNothing);
}

/// 열린 근거 시트가 받은 원국 개인 해석의 자리.
PersonalReadingKey? _personalKey(WidgetTester tester) =>
    tester.widget<EvidenceSheet>(find.byType(EvidenceSheet)).personal;

/// 근거 시트의 "내 사주에서는" 문장에 [text]가 있는지.
Finder _personalText(String text) =>
    _inEvidence(find.textContaining(text, findRichText: true));

/// member 사전에 12운성·신살 범주를 더한 사전(writing #331 원고가 온 뒤를 흉내 냄).
Future<GlossaryNames> _glossaryWithStages() async {
  final json = jsonDecode(
    File('fixtures/member/getGlossary.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final body = json['body'] as Map<String, dynamic>;
  final values = {
    for (final entry in (body['values'] as Map<String, dynamic>).entries)
      entry.key: Map<String, String>.from(entry.value as Map),
  };
  values['twelve_stage'] = const {'yang': '양', 'mokyok': '목욕'};
  values['shinsal'] = const {'hwagae': '화개'};
  return GlossaryNames(values);
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
        {'kind': 'added_after_freeze', 'position': 'day_branch'},
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
    expect(
      (pillars.day.stemLabel! as TermToken).label,
      _ko.sajuPillarDayMaster,
    );
    expect(pillars.tableLabel, _ko.sajuPillarsTableLabel);

    // 오행 분포: 목·화·토·금·수, 값은 소수 한 자리.
    final bar = tester.widget<OhaengBar>(_inChart(find.byType(OhaengBar)));
    final counts = {for (final item in bar.items) item.element: item.count};
    expect(counts[FiveElement.wood], '0.6');
    expect(counts[FiveElement.fire], '3.3');
    expect(counts[FiveElement.metal], '2.9');
    expect(bar.semanticLabel, startsWith('목 0.6, 화 3.3'));

    // 잠긴 용신 판정 근거: 이름 + 흐린 한 줄 + "열기".
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
    expect(manse.year.hiddenStems.map((stem) => stem.hanja), ['丁', '己']);
    expect(manse.day.stem?.hanja, '庚');
    expect(manse.tableLabel, _ko.manseTableLabel);

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
    final link = depthLinkTarget(
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
    await tester.tap(
      _inChart(find.bySemanticsIdentifier(SlotIds.sajuChartYongsinOpen)),
    );
    await settleWithIo(tester);
    expect(_evidenceSheet, findsOneWidget);
    expect(_inEvidence(find.byType(EvidenceLockPanel)), findsOneWidget);
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
    await tester.tap(
      _inChart(find.bySemanticsIdentifier(SlotIds.sajuChartYongsinOpen)),
    );
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

    // 시트를 닫으면 사주 표의 용신 판정 근거가 문장으로 보입니다.
    await _closeSheet(tester, _evidenceSheet);
    final basis = tester.widget<SentenceBlock>(_yongsinBasis);
    expect(basis.locked, isFalse);
    expect(
      _inChart(find.textContaining('정했어요', findRichText: true)),
      findsOneWidget,
    );
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

  testWidgets('evidence-unlocked: 일간 → 일간(천간) 풀이 → 근거 보기 → 일간 개인 해석', (
    tester,
  ) async {
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    final pillars = tester.widget<SajuPillars>(
      _inChart(find.byType(SajuPillars)),
    );
    await _openPersonal(tester, find.byWidget(pillars.day.stemLabel!));
    // 풀이 시트 제목은 일간(庚)의 이름입니다.
    expect(
      find.descendant(
        of: find.byKey(const Key(ScreenIds.explainSheet)),
        matching: find.text('경'),
      ),
      findsWidgets,
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
    await _openFromMySaju(tester, scenario: 'evidence-unlocked');
    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    // 연지 午의 지장간 丁(정관)·己(정인). 둘째(己)의 십성을 누릅니다.
    final label = manse.year.hiddenStems[1].label;
    expect(label, isA<TermToken>());
    expect((label! as TermToken).label, '정인');
    // 사전에 12운성·신살 이름이 없으면 칸을 비우고(A65) 줄 머리는 누를 수 없는 라벨입니다.
    expect(manse.year.twelveStage, isNull);
    expect(manse.hiddenStemsHeader, isNot(isA<TermToken>()));

    await _openPersonal(tester, find.byWidget(label));
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
    expect(daeun.daeun[3].branchLabel, isA<TermToken>());
    await _openPersonal(tester, find.byWidget(daeun.daeun[3].stemLabel!));
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
    await _openPersonal(tester, find.byWidget(daeun.seun[3].label!));
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindSeunTenGod,
        index: 3,
      ),
    );
    expect(_personalText('이 세운 자리는'), findsOneWidget);
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
    expect(manse.day.twelveStage, isA<TermToken>());
    expect((manse.day.shinsal.single as TermToken).label, '화개');

    await _openPersonal(tester, find.byWidget(manse.day.twelveStage!));
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindTwelveStage,
        position: Position.dayBranch,
      ),
    );
    expect(_personalText('이 12운성 자리는'), findsOneWidget);

    // 근거 시트와 풀이 시트를 닫고 신살 칸을 누릅니다.
    await _closeSheet(tester, _evidenceSheet);
    await _closeSheet(tester, find.byKey(const Key(ScreenIds.explainSheet)));
    final shinsal = tester
        .widget<ManseTable>(_inChart(find.byType(ManseTable)))
        .day
        .shinsal
        .single;
    await _openPersonal(tester, find.byWidget(shinsal));
    expect(
      _personalKey(tester),
      const PersonalReadingKey(
        kind: PersonalReadingKindEnum.PersonalReadingKindShinsal,
        position: Position.dayBranch,
        shinsal: ShinsalKind.hwagae,
      ),
    );
    expect(_personalText('이 신살 자리는'), findsOneWidget);
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
          });
        }),
      ],
    );
    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    expect(manse.day.shinsal, hasLength(1));
    expect((manse.day.shinsal.single as TermToken).label, '화개');
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
    final banner = tester.widget<NoticeBanner>(
      _inChart(find.byType(NoticeBanner)),
    );
    expect(banner.variant, NoticeBannerVariant.timeUnknown);
    expect(banner.message, _ko.sajuChartTimeUnknownNotice);
    final pillars = tester.widget<SajuPillars>(
      _inChart(find.byType(SajuPillars)),
    );
    expect(pillars.hour.stem, isNull);
    expect(pillars.hour.branch, isNull);

    await _openLuckTab(tester);
    final manse = tester.widget<ManseTable>(_inChart(find.byType(ManseTable)));
    expect(manse.hour.empty, isTrue);
    expect(_inChart(find.byType(NoticeBanner)), findsOneWidget);
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
