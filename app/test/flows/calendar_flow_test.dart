import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/calendar/presentation/calendar_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';

final _ko = AppLocalizationsKo();
final _today = CalendarDate(2026, 10, 13);

/// 달 길흉 요청 경로(`/v1/calendar/2026/10`)를 남기고, [hold]의 경로는 그 Completer가
/// 끝날 때까지 붙잡습니다. [offline]이 켜지면 모든 요청을 연결 오류로 끊습니다.
final class _Network extends Interceptor {
  final calendarPaths = <String>[];

  /// 일정·일기 목록 요청의 query(`from`·`to`).
  final listQueries = <String, List<Map<String, dynamic>>>{};
  final hold = <String, Completer<void>>{};
  bool offline = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (offline) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: '테스트: 연결이 끊겼습니다.',
        ),
        true,
      );
      return;
    }
    if (options.path == '/v1/schedules' || options.path == '/v1/diaries') {
      listQueries
          .putIfAbsent(options.path, () => [])
          .add(Map.of(options.queryParameters));
    }
    if (options.path.startsWith('/v1/calendar/')) {
      calendarPaths.add(options.path);
      final gate = hold[options.path];
      if (gate != null) {
        await gate.future;
      }
    }
    handler.next(options);
  }
}

/// 손으로 바꾸는 "오늘". 화면이 열린 채 자정을 넘기는 것을 흉내 냅니다.
final class _TestToday extends Notifier<CalendarDate> {
  new(this._start);

  final CalendarDate _start;

  @override
  CalendarDate build() => _start;

  CalendarDate get date => state;

  set date(CalendarDate value) => state = value;
}

/// [start]에서 시작하는 손 "오늘"과 그것을 [todayProvider]에 잇는 override.
({NotifierProvider<_TestToday, CalendarDate> provider, Override override})
_todayFrom(CalendarDate start) {
  final provider = NotifierProvider<_TestToday, CalendarDate>(
    () => _TestToday(start),
  );
  return (
    provider: provider,
    override: todayProvider.overrideWith((ref) => ref.watch(provider)),
  );
}

/// [scenario]로 앱을 띄우고 달력 탭으로 갑니다. [network]는 대역 서버 바로 앞에 끼웁니다.
Future<ProviderContainer> _openCalendar(
  WidgetTester tester, {
  String scenario = 'member',
  _Network? network,
  List<Override> overrides = const [],
  bool allowOngoing = false,
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
  await tester.tap(find.byKey(const ValueKey('tab-bar.tab.1')));
  await settleWithIo(tester, allowOngoing: allowOngoing);
  expect(find.byKey(const ValueKey(ScreenIds.calendar)), findsOneWidget);
  return container;
}

CalendarMonthView _monthView(WidgetTester tester) =>
    tester.widget<CalendarMonthView>(find.byType(CalendarMonthView));

DayCell _cell(WidgetTester tester, CalendarDate date) => tester.widget<DayCell>(
  find.descendant(
    of: find.byKey(CalendarMonthView.cellKey(date)),
    matching: find.byType(DayCell),
  ),
);

final Finder _offlineBanner = find.byWidgetPredicate(
  (widget) =>
      widget is NoticeBanner &&
      widget.variant == NoticeBannerVariant.offline &&
      widget.present,
);

void main() {
  testWidgets('member: 오늘이 든 달, 오늘 선택, 칸의 길흉·음력·절기·도장·점과 범례', (tester) async {
    covers(const Covers(decisions: ['D18', 'D48']));
    final handle = tester.ensureSemantics();
    await _openCalendar(tester);

    expect(find.bySemanticsIdentifier(ScreenIds.calendar), findsOneWidget);
    await expectAppBarTitle(
      tester,
      SlotIds.calendarBarTitle,
      _ko.calendarBarTitle,
    );

    final view = _monthView(tester);
    expect(view.month, const CalendarMonth(2026, 10));
    expect(view.title, '2026년 10월');
    expect(view.weekdayLabels, ['일', '월', '화', '수', '목', '금', '토']);
    expect(view.today, _today);
    expect(view.selected, _today);
    expect(view.loading, isFalse);

    final today = _cell(tester, _today);
    expect(today.isToday, isTrue);
    expect(today.isSelected, isTrue);
    expect(today.data.luck, DayLuck.good);
    expect(today.data.lunarText, '3');
    expect(today.data.eventCount, 3);
    expect(today.data.semanticLabel, contains('잘 풀리는 날'));
    expect(today.data.semanticLabel, contains('오늘'));

    // 초하루는 'M.1', 절기 날은 절기 이름 굵게(A40), 일기 쓴 날은 도장(A33).
    expect(_cell(tester, CalendarDate(2026, 10, 11)).data.lunarText, '9.1');
    final hallo = _cell(tester, CalendarDate(2026, 10, 8)).data;
    expect(hallo.lunarText, '한로');
    expect(hallo.lunarBold, isTrue);
    expect(hallo.diaryWritten, isTrue);
    expect(_cell(tester, CalendarDate(2026, 10, 3)).data.luck, DayLuck.caution);
    expect(_cell(tester, CalendarDate(2026, 10, 20)).data.eventCount, 1);

    // 범례 두 줄(A39).
    expect(view.legendIdentifier, SlotIds.calendarLegendBody);
    expect(
      [for (final entry in view.legend!) entry.label],
      [_ko.calendarLegendBodyGood, _ko.calendarLegendBodyCaution],
    );
    expect(find.bySemanticsIdentifier(SlotIds.calendarLegendBody), findsOne);
    handle.dispose();
  });

  testWidgets('member: 날짜를 누르면 선택하고 그날 시트를 엽니다', (tester) async {
    covers(const Covers(exits: ['calendar>day-sheet']));
    await _openCalendar(tester);

    final date = CalendarDate(2026, 10, 20);
    await tester.tap(find.byKey(CalendarMonthView.cellKey(date)));
    await settleWithIo(tester);

    expect(find.byKey(const Key(ScreenIds.daySheet)), findsOneWidget);
    expect(_monthView(tester).selected, date);
    expect(_cell(tester, date).isSelected, isTrue);
    expect(_cell(tester, _today).isSelected, isFalse);
  });

  testWidgets('member: 일정 추가 → 선택한 날의 event-edit', (tester) async {
    covers(const Covers(exits: ['calendar>event-edit']));
    final container = await _openCalendar(tester);
    final add = find.byKey(CalendarScreen.eventAddKey);
    expect(
      tester.widget<AppBarAction>(add).semanticLabel,
      _ko.daySheetEventAdd,
    );

    // 처음에는 오늘이 선택돼 있습니다.
    await tester.tap(add);
    await settleWithIo(tester);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/event-edit?date=2026-10-13',
    );
    container.read(routerProvider).pop();
    await settleWithIo(tester);

    // 다른 날을 고른 뒤에는 그 날입니다(그날 시트는 닫고 앱 바에서 추가).
    await tester.tap(
      find.byKey(CalendarMonthView.cellKey(CalendarDate(2026, 10, 21))),
    );
    await settleWithIo(tester);
    await tester.tapAt(const Offset(10, 10));
    await settleWithIo(tester);
    expect(find.byKey(const Key(ScreenIds.daySheet)), findsNothing);
    await tester.tap(add);
    await settleWithIo(tester);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/event-edit?date=2026-10-21',
    );
  });

  testWidgets('member: 다음 달로 넘기면 그 달을 보이고 그 앞뒤 달을 미리 받습니다', (tester) async {
    final network = _Network();
    await _openCalendar(tester, network: network);
    // 처음 달과 그 앞뒤 달.
    expect(
      network.calendarPaths,
      containsAll([
        '/v1/calendar/2026/10',
        '/v1/calendar/2026/9',
        '/v1/calendar/2026/11',
      ]),
    );

    await tester.tap(find.byKey(CalendarMonthView.nextKey));
    await settleWithIo(tester);

    final view = _monthView(tester);
    expect(view.month, const CalendarMonth(2026, 11));
    expect(view.title, '2026년 11월');
    expect(view.loading, isFalse);
    expect(network.calendarPaths, contains('/v1/calendar/2026/12'));
    expect(_cell(tester, CalendarDate(2026, 11, 2)).data.luck, isNotNull);
  });

  testWidgets('member: 달을 받는 동안 격자 skeleton입니다', (tester) async {
    covers(const Covers(states: ['calendar:loading']));
    final network = _Network();
    final gate = Completer<void>();
    network.hold['/v1/calendar/2026/10'] = gate;
    await _openCalendar(tester, network: network, allowOngoing: true);
    await tester.pump(const Duration(milliseconds: 400));

    expect(_monthView(tester).loading, isTrue);
    expect(find.byKey(CalendarMonthView.fillBoneKey), findsWidgets);
    expect(_cell(tester, _today).data.luck, isNull);

    gate.complete();
    await settleWithIo(tester);
    expect(_monthView(tester).loading, isFalse);
    expect(_cell(tester, _today).data.luck, DayLuck.good);
  });

  testWidgets('calendar-error: 오류와 다시 시도', (tester) async {
    covers(const Covers(states: ['calendar:error']));
    final network = _Network();
    await _openCalendar(tester, scenario: 'calendar-error', network: network);

    final error = find.descendant(
      of: find.byKey(const ValueKey(ScreenIds.calendar)),
      matching: find.byType(ErrorState),
    );
    expect(error, findsOneWidget);
    expect(tester.widget<ErrorState>(error).variant, ErrorStateVariant.generic);
    // 달 넘김은 그대로 쓸 수 있습니다.
    expect(find.byType(CalendarMonthView), findsOneWidget);

    final before = network.calendarPaths
        .where((path) => path == '/v1/calendar/2026/10')
        .length;
    final retry = find.descendant(
      of: error,
      matching: find.text(_ko.actionRetry),
    );
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await settleWithIo(tester);
    expect(
      network.calendarPaths.where((path) => path == '/v1/calendar/2026/10'),
      hasLength(before + 1),
    );
    expect(error, findsOneWidget);
  });

  testWidgets('offline: 받아 둔 달은 배너와 함께, 받은 적 없는 달은 오류입니다', (tester) async {
    covers(const Covers(states: ['calendar:offline']));
    final network = _Network();
    await _openCalendar(tester, network: network);
    expect(_offlineBanner, findsNothing);

    // 연결이 끊긴 뒤 미리 받아 둔 다음 달로 넘깁니다.
    network.offline = true;
    await tester.tap(find.byKey(CalendarMonthView.nextKey));
    await settleWithIo(tester);
    expect(_monthView(tester).month, const CalendarMonth(2026, 11));
    expect(_cell(tester, CalendarDate(2026, 11, 2)).data.luck, isNotNull);
    expect(_offlineBanner, findsOneWidget);
    expect(find.text(_ko.noticeOffline), findsOneWidget);

    // 받은 적 없는 달은 오프라인 오류와 다시 시도입니다.
    await tester.tap(find.byKey(CalendarMonthView.nextKey));
    await settleWithIo(tester);
    expect(_monthView(tester).month, const CalendarMonth(2026, 12));
    final error = tester.widget<ErrorState>(find.byType(ErrorState));
    expect(error.variant, ErrorStateVariant.offline);
    expect(error.onRetry, isNotNull);

    // 연결이 돌아온 뒤 배너만 떴던 달로 돌아가면 오류로 남은 일정 범위를 다시 받습니다.
    network.offline = false;
    await tester.tap(find.byKey(CalendarMonthView.prevKey));
    await settleWithIo(tester);
    expect(_monthView(tester).month, const CalendarMonth(2026, 11));
    expect(_offlineBanner, findsNothing);
  });

  testWidgets('offline에서 연 달은 연결이 돌아온 뒤 다시 시도로 길흉·점·도장이 다 보입니다', (
    tester,
  ) async {
    covers(const Covers(states: ['calendar:offline', 'calendar:error']));
    final network = _Network();
    final container = await pumpApp(tester, scenario: 'member');
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
    network.offline = true;
    await tester.tap(find.byKey(const ValueKey('tab-bar.tab.1')));
    await settleWithIo(tester);
    final error = find.byType(ErrorState);
    expect(tester.widget<ErrorState>(error).variant, ErrorStateVariant.offline);

    network.offline = false;
    await tester.tap(
      find.descendant(of: error, matching: find.text(_ko.actionRetry)),
    );
    await settleWithIo(tester);
    expect(find.byType(ErrorState), findsNothing);
    expect(_offlineBanner, findsNothing);
    final today = _cell(tester, _today).data;
    expect(today.luck, DayLuck.good);
    expect(today.eventCount, 3);
    expect(_cell(tester, CalendarDate(2026, 10, 12)).data.diaryWritten, isTrue);
  });

  testWidgets('작은 화면에서도 오류와 다시 시도가 스크롤 없이 보입니다', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openCalendar(tester, scenario: 'calendar-error');

    final retry = tester.getRect(find.text(_ko.actionRetry));
    final barTop = tester
        .getRect(find.byKey(const ValueKey('bottom-bar.surface')))
        .top;
    expect(retry.top, greaterThanOrEqualTo(0));
    expect(retry.bottom, lessThanOrEqualTo(barTop));
  });

  testWidgets('잠금 해제 정리로 다시 받는 동안 skeleton으로 깜빡이지 않습니다', (tester) async {
    final network = _Network();
    final container = await _openCalendar(tester, network: network);
    network.hold['/v1/calendar/2026/10'] = Completer<void>();

    await tester.runAsync(
      () => container.read(calendarUnlockSyncProvider).forgetLocked(),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_monthView(tester).loading, isFalse);
      expect(_cell(tester, _today).data.luck, DayLuck.good);
    }
    expect(find.byKey(CalendarMonthView.fillBoneKey), findsNothing);
    network.hold.remove('/v1/calendar/2026/10')!.complete();
    await settleWithIo(tester);
    expect(_cell(tester, _today).data.luck, DayLuck.good);
  });

  testWidgets('빠르게 넘겼다 돌아오면 늦게 온 다른 달 응답이 보이는 달을 덮지 않습니다', (tester) async {
    final network = _Network();
    final gate = Completer<void>();
    network.hold['/v1/calendar/2026/11'] = gate;
    await _openCalendar(tester, network: network);

    await tester.tap(find.byKey(CalendarMonthView.nextKey));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_monthView(tester).month, const CalendarMonth(2026, 11));
    await tester.tap(find.byKey(CalendarMonthView.prevKey));
    await tester.pump(const Duration(milliseconds: 50));

    gate.complete();
    await settleWithIo(tester);
    final view = _monthView(tester);
    expect(view.month, const CalendarMonth(2026, 10));
    expect(view.title, '2026년 10월');
    expect(_cell(tester, _today).data.luck, DayLuck.good);
  });

  testWidgets('2099-12에서는 다음 달로 가지 않고 일정·일기는 2099-12-31까지만 묻습니다(D41)', (
    tester,
  ) async {
    final network = _Network();
    await _openCalendar(
      tester,
      network: network,
      overrides: [_todayFrom(CalendarDate(2099, 12, 15)).override],
    );
    expect(_monthView(tester).month, const CalendarMonth(2099, 12));
    await tester.tap(find.byKey(CalendarMonthView.nextKey));
    await settleWithIo(tester);
    expect(_monthView(tester).month, const CalendarMonth(2099, 12));

    for (final path in ['/v1/schedules', '/v1/diaries']) {
      final query = network.listQueries[path]!.last;
      expect(query['from'], '2099-11-29', reason: path);
      expect(query['to'], '2099-12-31', reason: path);
    }
  });

  testWidgets('1900-01에서는 이전 달로 가지 않고 일정·일기는 1900-01-31부터 묻습니다(D41)', (
    tester,
  ) async {
    final network = _Network();
    await _openCalendar(
      tester,
      network: network,
      overrides: [_todayFrom(CalendarDate(1900, 1, 31)).override],
    );
    expect(_monthView(tester).month, const CalendarMonth(1900, 1));
    await tester.tap(find.byKey(CalendarMonthView.prevKey));
    await settleWithIo(tester);
    expect(_monthView(tester).month, const CalendarMonth(1900, 1));

    for (final path in ['/v1/schedules', '/v1/diaries']) {
      final query = network.listQueries[path]!.last;
      expect(query['from'], '1900-01-31', reason: path);
      expect(query['to'], '1900-02-10', reason: path);
    }
  });

  testWidgets('날을 고른 뒤 달 경계 자정을 넘겨도 고른 날의 달에 머뭅니다', (tester) async {
    final today = _todayFrom(CalendarDate(2026, 10, 31));
    final container = await _openCalendar(tester, overrides: [today.override]);
    final picked = CalendarDate(2026, 10, 20);
    await tester.tap(find.byKey(CalendarMonthView.cellKey(picked)));
    await settleWithIo(tester);
    await tester.tapAt(const Offset(10, 10));
    await settleWithIo(tester);

    container.read(today.provider.notifier).date = CalendarDate(2026, 11, 1);
    await settleWithIo(tester);
    final view = _monthView(tester);
    expect(view.month, const CalendarMonth(2026, 10));
    expect(view.selected, picked);
    expect(_cell(tester, picked).isSelected, isTrue);
  });

  testWidgets('화면을 연 채 자정을 넘기면 오늘 윤곽이 옮겨 갑니다', (tester) async {
    final today = _todayFrom(_today);
    final container = await _openCalendar(tester, overrides: [today.override]);
    expect(_cell(tester, _today).isToday, isTrue);

    final tomorrow = CalendarDate(2026, 10, 14);
    container.read(today.provider.notifier).date = tomorrow;
    await settleWithIo(tester);
    expect(_cell(tester, _today).isToday, isFalse);
    expect(_cell(tester, tomorrow).isToday, isTrue);
    expect(_monthView(tester).today, tomorrow);
  });

  testWidgets('탭 셸 아래 배너 자리를 비워 범례가 하단 틀에 가리지 않습니다', (tester) async {
    await _openCalendar(tester);
    final bar = tester.widget<MyungliBottomBar>(find.byType(MyungliBottomBar));
    expect(bar.showAd, isTrue);

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey(ScreenIds.calendar)),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, -2000));
    await tester.pumpAndSettle();

    final legend = tester.getRect(
      find.byKey(const ValueKey<String>(SlotIds.calendarLegendBody)),
    );
    final barTop = tester
        .getRect(find.byKey(const ValueKey('bottom-bar.surface')))
        .top;
    expect(legend.bottom, lessThanOrEqualTo(barTop));
  });
}
