import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/diary/diary_summary.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/features/me/application/diary_stats_provider.dart';
import 'package:myungli_diary/features/me/presentation/my_saju_screen.dart';
import 'package:myungli_diary/features/me/presentation/saju_chart_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/chart_network.dart';
import '../support/my_saju_finders.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

/// [scenario]로 앱을 띄우고 나 탭을 엽니다.
Future<ProviderContainer> _openMe(
  WidgetTester tester, {
  String scenario = 'member',
  Interceptor? network,
  bool settle = true,
  List<Override> overrides = const [],
}) async {
  // 다섯 섹션이 한 번에 놓이게 세로로 긴 화면을 씁니다(ListView는 화면 밖을 그리지 않음).
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(1170, 9000);
  addTearDown(tester.view.reset);
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
  // 응답을 붙잡아 두면(settle false) skeleton이 계속 숨 쉬므로 움직임이 이어져도 돌아갑니다.
  await pumpUntil(
    tester,
    () => find.byKey(const ValueKey(ScreenIds.mySaju)).evaluate().isNotEmpty,
    allowOngoing: !settle,
  );
  if (settle) {
    await pumpUntil(
      tester,
      () =>
          find.byType(OhaengCell).evaluate().isNotEmpty ||
          find.byType(ErrorState).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
  }
  return container;
}

/// 받은 나의 사주에서 문장 필드(draft.10, 선택)를 뺍니다.
final class _DropSentences extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/chart' && data is Map) {
      response.data = Map<String, Object?>.of(data.cast<String, Object?>())
        ..remove('ilganHead')
        ..remove('ilganBody')
        ..remove('yongsinSummary');
    }
    handler.next(response);
  }
}

/// [slotId] 문장 덩어리.
Finder _block(String slotId) => find.byWidgetPredicate(
  (widget) => widget is SentenceBlock && widget.slotId == slotId,
);

/// 사전과 한자 표에 없는 태그 키.
const unknownTagKey = 'no_such_tag';

/// 회고 집계(`/v1/me/diary-stats`) 요청을 [fail]이면 503으로 끊는 대역.
final class _DiaryStatsNetwork extends Interceptor {
  /// 503으로 답할지.
  bool fail = true;

  /// 지금까지 받은 요청 수.
  int requests = 0;

  /// 성공 응답의 자주 붙은 태그에 사전에 없는 태그([unknownTagKey])를 더할지.
  bool addUnknownTag = false;

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (addUnknownTag &&
        response.requestOptions.path.endsWith('diary-stats') &&
        data is Map) {
      final map = Map<String, Object?>.of(data.cast<String, Object?>());
      map['topTags'] = [
        ...(map['topTags']! as List<Object?>),
        {
          'tag': {'key': unknownTagKey, 'polarity': 'good'},
          'days': 1,
        },
      ];
      response.data = map;
    }
    handler.next(response);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.endsWith('diary-stats')) {
      requests++;
      if (fail) {
        handler.reject(serviceUnavailable(options));
        return;
      }
    }
    handler.next(options);
  }
}

/// 받은 나의 사주에서 대운 목록을 비웁니다(대운이 없는 차트).
final class _DropDaeun extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/chart' && data is Map) {
      final map = Map<String, Object?>.of(data.cast<String, Object?>());
      map['daeun'] = {
        ...(map['daeun']! as Map<String, Object?>),
        'periods': <Object?>[],
      };
      response.data = map;
    }
    handler.next(response);
  }
}

/// 기기 오늘을 2026-06-15로 고정합니다(fixture 지금 대운 2023~2032, 출생 연도 1990).
final Override _fixedToday = todayProvider.overrideWith(
  (ref) => CalendarDate(2026, 6, 15),
);

Finder get _screen => find.byKey(const ValueKey(ScreenIds.mySaju));

/// 나 탭 안에서 [matching]을 찾습니다.
Finder _inScreen(Finder matching) =>
    find.descendant(of: _screen, matching: matching);

/// [finder]가 화면에 들어오게 스크롤합니다.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: _inScreen(find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('제목, 원국 카드, 용신 줄과 행운 색', (tester) async {
    covers(const Covers(decisions: ['D16']));
    await _openMe(tester);
    await expectAppBarTitle(tester, SlotIds.mySajuBarTitle, _ko.mySajuBarTitle);
    expect(
      find.descendant(of: find.byType(SajuPillars), matching: find.text('庚')),
      findsWidgets,
    );
    expect(find.text('나와 잘 맞는 기운'), findsOneWidget);
    expect(find.text('수'), findsWidgets);
    final chip = tester.widget<LuckyChip>(find.byType(LuckyChip));
    expect(chip.item.value, '남색');
  });

  testWidgets('섹션 제목 다섯이 위에서 원국, 성향 풀이, 돕는 기운, 올해와 지금, 회고 순서입니다', (
    tester,
  ) async {
    covers(const Covers(decisions: ['V76', 'V77']));
    await _openMe(tester);
    final titles = [
      _ko.mySajuChartTitle,
      _ko.mySajuIlganTitle,
      _ko.mySajuYongsinTitle,
      _ko.mySajuFlowTitle,
      _ko.mySajuRecordTitle,
    ];
    for (final title in titles) {
      final finder = _inScreen(
        find.descendant(
          of: find.byType(SectionHeader),
          matching: find.text(title),
        ),
      );
      await _reveal(tester, finder);
      expect(finder, findsOneWidget);
    }
    // 제목은 위젯 트리 순서(위에서 아래)대로 다섯입니다.
    final headers = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .map((header) => header.title)
        .toList();
    expect(headers, titles);
    // "근거 보기" 줄은 없습니다.
    expect(find.byType(DepthLink), findsNothing);
  });

  testWidgets('문장 필드가 있으면 일간 소개 첫 문장은 card, 이어지는 문장과 용신 설명은 body입니다', (
    tester,
  ) async {
    await _openMe(tester);
    final head = _block(SlotIds.mySajuIlganHead);
    final body = _block(SlotIds.mySajuIlganBody);
    final summary = _block(SlotIds.mySajuYongsinBody);
    expect(
      tester.widget<SentenceBlock>(head).variant,
      SentenceBlockVariant.card,
    );
    for (final finder in [body, summary]) {
      expect(finder, findsOneWidget);
      expect(
        tester.widget<SentenceBlock>(finder).variant,
        SentenceBlockVariant.body,
      );
    }
    expect(
      find.textContaining('하늘님, 다듬기 전의', findRichText: true),
      findsOneWidget,
    );
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final order = [head, body, find.byType(LuckyChip), summary].map(top);
    expect(order.toList(), orderedEquals([...order]..sort()));
  });

  testWidgets('문장 필드가 없으면(선택) 그 자리를 그리지 않습니다', (tester) async {
    await _openMe(tester, network: _DropSentences());
    expect(_block(SlotIds.mySajuIlganHead), findsNothing);
    expect(_block(SlotIds.mySajuIlganBody), findsNothing);
    expect(_block(SlotIds.mySajuYongsinBody), findsNothing);
    expect(find.byType(LuckyChip), findsOneWidget);
  });

  testWidgets('용신 오행 용어 → 풀이 시트', (tester) async {
    covers(const Covers(exits: ['my-saju>explain-sheet']));
    await _openMe(tester);
    final term = find.byWidgetPredicate(
      (widget) =>
          widget is TermToken &&
          widget.label == '수' &&
          widget.variant == TermTokenVariant.inline,
    );
    await tester.tap(term.first);
    await settleWithIo(tester);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
  });

  testWidgets('올해와 지금: 지금 대운과 올해 세운이 compact로 있고 낭독에 칩 낱말이 없습니다', (
    tester,
  ) async {
    covers(const Covers(decisions: ['V77']));
    await _openMe(tester);
    final pillars = find.byType(LuckPillar);
    await _reveal(tester, pillars.first);
    expect(pillars, findsNWidgets(2));
    final daeun = tester.widget<LuckPillar>(pillars.first);
    final seun = tester.widget<LuckPillar>(pillars.last);
    expect(daeun.tagLabel, _ko.daeunTagNow);
    expect(daeun.kindLabel, _ko.sajuChartDaeunTitle);
    expect(daeun.tenGods, hasLength(2));
    expect(seun.tagLabel, _ko.seunTagThisYear);
    expect(seun.kindLabel, _ko.sajuChartSeunTitle);
    expect(seun.tenGods, hasLength(1));
    // 한국식 나이("만" 없음).
    expect(daeun.period, isNot(contains('만')));
    expect(seun.period, allOf(contains('년'), contains('세')));
    // 칩이 따로 button이라 그룹 낭독에는 십성과 대운, 세운 낱말을 넣지 않습니다.
    for (final (pillar, kind) in [
      (daeun, _ko.sajuChartDaeunTitle),
      (seun, _ko.sajuChartSeunTitle),
    ]) {
      expect(pillar.semanticLabel, isNot(contains(kind)));
      for (final god in pillar.tenGods) {
        expect(pillar.semanticLabel, isNot(contains(god.text)));
      }
    }
  });

  testWidgets('십성 칩과 대운 칩 → 풀이 시트', (tester) async {
    covers(const Covers(exits: ['my-saju>explain-sheet']));
    await _openMe(tester);
    final pillars = find.byType(LuckPillar);
    await _reveal(tester, pillars.first);
    final god = tester.widget<LuckPillar>(pillars.first).tenGods.first;
    await tester.tap(
      find.descendant(of: pillars.first, matching: find.text(god.text)),
    );
    await settleWithIo(tester);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
  });

  testWidgets('사주 표 링크 → 사주 표 원국 탭', (tester) async {
    covers(const Covers(exits: ['my-saju>saju-chart']));
    await _openMe(tester);
    await tester.tap(mySajuChartLink(of: _screen));
    await pumpUntilScreen(tester, ScreenIds.sajuChart);
    await settleWithIo(tester);
    expect(find.byType(SajuPillars), findsWidgets);
    expect(find.byType(ManseTable), findsNothing);
  });

  testWidgets('대운 전체 → 사주 표 만세력과 대운 탭이 선택된 채 열립니다(A117)', (tester) async {
    covers(const Covers(exits: ['my-saju>saju-chart'], decisions: ['A117']));
    await _openMe(tester);
    final link = mySajuFlowLink(of: _screen);
    await _reveal(tester, link);
    await tester.tap(link);
    await pumpUntilScreen(tester, ScreenIds.sajuChart);
    await settleWithIo(tester);
    expect(find.byType(ManseTable), findsOneWidget);
    expect(find.byType(DaeunTable), findsOneWidget);
    final segmented = tester.widget<Segmented<SajuChartTab>>(
      find.byType(Segmented<SajuChartTab>),
    );
    expect(segmented.selected, SajuChartTab.luck);
  });

  testWidgets('회고: 집계를 받으면 diary-summary, 태그를 누르면 뜻 시트와 모아보기 링크(A119)', (
    tester,
  ) async {
    covers(const Covers(exits: ['my-saju>explain-sheet'], decisions: ['V76']));
    await _openMe(tester);
    final summary = find.byType(DiarySummary);
    await _reveal(tester, summary);
    expect(summary, findsOneWidget);
    final tag = find.descendant(of: summary, matching: find.byType(HanjaTag));
    expect(tag, findsWidgets);
    final name = tester.widget<HanjaTag>(tag.first).label;
    await tester.tap(tag.first);
    await settleWithIo(tester);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
    final diaryLink = find.textContaining(_ko.explainSheetTagDiaryLink(name));
    expect(diaryLink, findsOneWidget);
    await tester.tap(diaryLink);
    await pumpUntilScreen(tester, ScreenIds.tagDiary);
  });

  testWidgets('회고 집계 실패: 회고 카드 자리에만 오류와 다시 시도, 다른 섹션은 그대로(A119)', (
    tester,
  ) async {
    final network = _DiaryStatsNetwork();
    await _openMe(tester, network: network);
    final error = find.byKey(MySajuScreen.recordErrorKey);
    await _reveal(tester, error);
    expect(error, findsOneWidget);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byType(DiarySummary), findsNothing);
    // 다른 섹션은 그대로입니다.
    expect(find.byType(SajuPillars), findsWidgets);
    expect(find.byType(LuckPillar), findsNWidgets(2));
    expect(_block(SlotIds.mySajuIlganHead), findsOneWidget);
    // 다시 시도하면 회고만 다시 받습니다.
    network.fail = false;
    final before = network.requests;
    await tester.tap(
      find.descendant(of: error, matching: find.text(_ko.actionRetry)),
    );
    await settleWithIo(tester);
    expect(network.requests, before + 1);
    expect(find.byKey(MySajuScreen.recordErrorKey), findsNothing);
    expect(find.byType(DiarySummary), findsOneWidget);
  });

  testWidgets('대운과 세운 기간 줄은 fixture 출생 연도(1990) 기준 한국식 나이입니다', (tester) async {
    covers(const Covers(decisions: ['V77']));
    await _openMe(tester, overrides: [_fixedToday]);
    final pillars = find.byType(LuckPillar);
    expect(pillars, findsNWidgets(2));
    expect(
      tester.widget<LuckPillar>(pillars.first).period,
      '34~43세 2023~2032년',
    );
    // 2026 - 1990 + 1 = 37.
    expect(tester.widget<LuckPillar>(pillars.last).period, '2026년 37세');
  });

  testWidgets('대운이 없으면 대운 줄은 없고 세운 줄은 연도만 보입니다', (tester) async {
    await _openMe(tester, network: _DropDaeun(), overrides: [_fixedToday]);
    final pillars = find.byType(LuckPillar);
    expect(pillars, findsOneWidget);
    final seun = tester.widget<LuckPillar>(pillars);
    expect(seun.tagLabel, _ko.seunTagThisYear);
    expect(seun.period, '2026년');
    expect(tester.takeException(), isNull);
  });

  testWidgets('사전에 없는 회고 태그는 crashReporter에 한 번만 기록됩니다(A112)', (tester) async {
    final reporter = FakeCrashReporter();
    final network = _DiaryStatsNetwork()..addUnknownTag = true;
    final container = await _openMe(
      tester,
      network: network,
      overrides: [crashReporterProvider.overrideWithValue(reporter)],
    );
    List<String?> gaps() => [
      for (final error in reporter.errors)
        if (error.errorType == 'MissingDictionaryEntry') error.code,
    ];
    // 처음에는 집계가 실패했으므로 기록이 없습니다.
    expect(gaps(), isEmpty);
    // 다시 시도로 받으면 한 번 기록됩니다.
    network.fail = false;
    final error = find.byKey(MySajuScreen.recordErrorKey);
    await _reveal(tester, error);
    await tester.tap(
      find.descendant(of: error, matching: find.text(_ko.actionRetry)),
    );
    await settleWithIo(tester);
    expect(gaps(), ['tag.$unknownTagKey']);
    // 재빌드와 집계 다시 읽기 뒤에도 늘지 않습니다.
    container.invalidate(diaryStatsProvider);
    await settleWithIo(tester);
    await tester.pumpAndSettle();
    expect(find.byType(DiarySummary), findsOneWidget);
    expect(gaps(), ['tag.$unknownTagKey']);
  });

  testWidgets('톱니 → 설정', (tester) async {
    covers(const Covers(exits: ['my-saju>settings']));
    await _openMe(tester);
    await tester.tap(find.byKey(MySajuScreen.settingsKey));
    await pumpUntilScreen(tester, ScreenIds.settings);
    expect(find.byKey(const ValueKey(ScreenIds.settings)), findsOneWidget);
  });

  testWidgets('time-unknown: 3주로 계산했다는 배너', (tester) async {
    covers(const Covers(states: ['my-saju:time-unknown']));
    await _openMe(tester, scenario: 'member-time-unknown');
    final banner = tester.widget<NoticeBanner>(find.byType(NoticeBanner).last);
    expect(banner.variant, NoticeBannerVariant.timeUnknown);
  });

  testWidgets('loading: 받는 동안 skeleton, 오면 내용', (tester) async {
    covers(const Covers(states: ['my-saju:loading']));
    final network = ChartNetwork()..hold = true;
    await _openMe(tester, network: network, settle: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(ScreenIds.mySaju)),
        matching: find.byKey(const ValueKey('screen-state.loading')),
      ),
      findsOneWidget,
    );
    network.gate.complete();
    await pumpUntil(
      tester,
      () => find.byType(OhaengCell).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
  });

  testWidgets('error: 받지 못하면 오류와 다시 시도', (tester) async {
    covers(const Covers(states: ['my-saju:error']));
    final network = ChartNetwork()..fail = true;
    await _openMe(tester, network: network);
    expect(find.byType(ErrorState), findsOneWidget);
    network.fail = false;
    await tester.tap(find.text(_ko.actionRetry));
    await pumpUntil(
      tester,
      () => find.byType(OhaengCell).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
    expect(find.byType(OhaengCell), findsWidgets);
  });
}
