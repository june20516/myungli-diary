import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
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
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
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

/// `/v1/chart`를 세고, [hold]면 [gate]까지 붙잡고, [fail]이면 503으로 답합니다.
final class _ChartNetwork extends Interceptor {
  bool hold = false;
  bool fail = false;
  int requests = 0;
  final gate = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path != '/v1/chart') {
      handler.next(options);
      return;
    }
    requests++;
    if (hold) await gate.future;
    if (fail) {
      handler.reject(
        DioException.badResponse(
          statusCode: 503,
          requestOptions: options,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 503,
            data: {
              'type': 'about:blank',
              'title': 'Unavailable',
              'status': 503,
              'code': 'service.unavailable',
              'traceId': 'test',
            },
            headers: Headers.fromMap({
              Headers.contentTypeHeader: ['application/problem+json'],
            }),
          ),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
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
  _ChartNetwork? network,
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
  await tester.ensureVisible(link);
  await tester.tap(link);
  await pumpUntilScreen(tester, ScreenIds.sajuChart);
  await _settleChart(tester);
  return container;
}

/// [network]를 끼운 뒤 오늘 화면에서 사주 표로 바로 갑니다(나의 사주가 먼저 받지 않게).
Future<ProviderContainer> _pushChart(
  WidgetTester tester,
  _ChartNetwork network, {
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
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
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
    final network = _ChartNetwork()..hold = true;
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
    final network = _ChartNetwork()..fail = true;
    await _pushChart(tester, network);
    expect(_inChart(find.byType(ErrorState)), findsOneWidget);
    network.fail = false;
    await tester.tap(_inChart(find.text(_ko.actionRetry)));
    await _settleChart(tester);
    expect(_inChart(find.byType(SajuPillars)), findsOneWidget);
  });

  testWidgets('올해가 바뀌면 새 연도로 다시 받고 올해 세운 강조가 새 해를 따릅니다', (tester) async {
    final today = testTodayProvider(CalendarDate(2026, 12, 31));
    final network = _ChartNetwork();
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
