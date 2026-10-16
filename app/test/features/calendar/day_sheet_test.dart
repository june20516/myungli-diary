import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/depth_sheet_bodies.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/sheet_registry.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/calendar/presentation/day_sheet_body.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';

import '../../support/schedule_test_server.dart';

final _ko = AppLocalizationsKo();

final _today = CalendarDate(2026, 10, 13);

/// member 시나리오의 2026년 10월 달 길흉.
Calendar _october() {
  final fixture = jsonDecode(
    File('fixtures/member/getCalendar__2026-10.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Calendar.fromJson(fixture['body'] as Map<String, dynamic>);
}

/// 시각순이 아니게 섞은 member 일정(저녁 → 아침 → 하루 종일).
List<Map<String, Object?>> _shuffledSchedules() {
  final seed = memberSchedules();
  return [seed[2], seed[1], seed[0], seed[3]];
}

/// 이동한 위치와 넘긴 일정 id를 보이는 자리 표시 화면.
Widget _visited(GoRouterState state) => Scaffold(
  body: Column(
    children: [
      Text('uri ${state.uri}'),
      Text('extra ${(state.extra as Schedule?)?.id}'),
    ],
  ),
);

/// day-sheet를 띄우는 앱. 첫 화면에서 [DaySheets.open]을 부를 수 있게 context를 돌려줍니다.
final class _Harness {
  new({
    required this.server,
    required this.calendar,
    required this.diaryExists,
  });

  final ScheduleTestServer server;
  final Future<Calendar> Function() calendar;
  final Future<bool> Function(CalendarDate date) diaryExists;

  final diaryChecks = <CalendarDate>[];
  final crash = FakeCrashReporter();
  final rootKey = GlobalKey<NavigatorState>();

  BuildContext get context => rootKey.currentContext!;

  late final GoRouter router = GoRouter(
    navigatorKey: rootKey,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.expand()),
      for (final id in [
        ScreenIds.eventEdit,
        ScreenIds.diaryView,
        ScreenIds.diaryEdit,
      ])
        GoRoute(path: pathOf(id), builder: (_, state) => _visited(state)),
    ],
  );

  Widget app() => ProviderScope(
    overrides: [
      restClientProvider.overrideWithValue(server.client()),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      todayProvider.overrideWithValue(_today),
      crashReporterProvider.overrideWithValue(crash),
      calendarMonthProvider.overrideWith((ref, month) => calendar()),
      diaryExistsOnProvider.overrideWith((ref, date) {
        diaryChecks.add(date);
        return diaryExists(date);
      }),
      daySheetBodyProvider.overrideWithValue(
        (date) => DaySheetBody(date: date),
      ),
      explainBodyProvider.overrideWithValue(
        (termId, sourceSlotId) => Text('풀이 $termId $sourceSlotId'),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(
        brightness: Brightness.light,
        locale: const Locale('ko'),
      ),
    ),
  );
}

Future<_Harness> _open(
  WidgetTester tester,
  CalendarDate date, {
  ScheduleTestServer? server,
  Future<Calendar> Function()? calendar,
  Future<bool> Function(CalendarDate date)? diaryExists,
}) async {
  tester.view
    ..physicalSize = const Size(400, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(
    server: server ?? ScheduleTestServer(seed: _shuffledSchedules()),
    calendar: calendar ?? () async => _october(),
    diaryExists: diaryExists ?? (_) async => false,
  );
  addTearDown(harness.router.dispose);
  await tester.pumpWidget(harness.app());
  final container = ProviderScope.containerOf(harness.context);
  unawaited(container.read(daySheetsProvider).open(harness.context, date));
  await tester.pumpAndSettle();
  return harness;
}

List<String> _rowTitles(WidgetTester tester) => [
  for (final row in tester.widgetList<EventRow>(find.byType(EventRow)))
    row.title,
];

void main() {
  group('DaySheets.open', () {
    testWidgets('화면 id가 Key·Semantics에 붙고 시트 이름은 그 날짜입니다', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, CalendarDate(2026, 10, 12));

      expect(find.byKey(const Key(ScreenIds.daySheet)), findsOneWidget);
      expect(find.bySemanticsIdentifier(ScreenIds.daySheet), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('10월 12일 월요일')), findsWidgets);
      semantics.dispose();
    });

    testWidgets('half 시트로 열립니다(긴 본문도 화면의 60%까지)', (tester) async {
      final harness = await _open(tester, CalendarDate(2026, 10, 12));
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      final tall = DaySheets(body: (_) => const SizedBox(height: 4000));
      unawaited(tall.open(harness.context, _today));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(MyungliSheetFrame)).height,
        closeTo(900 * sheetHalfFraction, 0.01),
      );
    });
  });

  group('DaySheetBody', () {
    testWidgets('성격 이름(ARB)과 이유 문장(용어는 칩)을 그립니다', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 12));

      final label = find.byKey(const ValueKey(SlotIds.daySheetCharacterLabel));
      expect(
        find.descendant(of: label, matching: find.byType(DayCharacter)),
        findsOneWidget,
      );
      expect(
        tester.widget<DayCharacter>(find.byType(DayCharacter)).label,
        _ko.dayKindGwiinDay,
      );
      final reason = find.byKey(
        const ValueKey(SlotIds.daySheetCharacterReason),
      );
      expect(
        tester
            .widget<SentenceBlock>(
              find.ancestor(of: reason, matching: find.byType(SentenceBlock)),
            )
            .text
            .segments
            .map((segment) => segment.text)
            .join(),
        '천을귀인이 들어 도와주는 사람이 곁에 오는 날이에요.',
      );
      expect(
        find.descendant(of: reason, matching: find.byType(TermToken)),
        findsOneWidget,
      );
    });

    testWidgets('시트에는 광고 배너가 없습니다(D53)', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 13));

      expect(find.byType(AdBanner), findsNothing);
      expect(find.byType(AdBannerFrame), findsNothing);
    });

    testWidgets('용어 칩을 누르면 근거 슬롯 없이(근거 보기 없음) 풀이 시트가 위로 쌓입니다', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 12));

      await tester.tap(find.byType(TermToken));
      await tester.pumpAndSettle();

      expect(find.text('풀이 tag.cheoneul_gwiin null'), findsOneWidget);
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
      expect(find.byKey(const Key(ScreenIds.daySheet)), findsOneWidget);
    });

    testWidgets('일정은 시각순이고 하루 종일이 먼저이며 마지막 줄은 구분선이 없습니다', (tester) async {
      await _open(tester, _today);

      expect(_rowTitles(tester), ['엄마 생신', '팀 주간 회의', '요가 수업']);
      final rows = tester.widgetList<EventRow>(find.byType(EventRow)).toList();
      expect(rows.map((row) => row.time), [null, '09:07', '19:00']);
      expect(rows.map((row) => row.showDivider), [true, true, false]);
      expect(find.byType(EventRowListEmpty), findsNothing);
    });

    testWidgets('일정을 누르면 그 일정으로 event-edit에 갑니다', (tester) async {
      final harness = await _open(tester, _today);

      await tester.tap(find.widgetWithText(EventRow, '팀 주간 회의'));
      await tester.pumpAndSettle();

      expect(find.text('uri /event-edit'), findsOneWidget);
      expect(find.text('extra morning'), findsOneWidget);
      expect(harness.router.state.uri.path, pathOf(ScreenIds.eventEdit));
    });

    testWidgets('일정이 있어도 일정 추가로 그날 event-edit에 갑니다', (tester) async {
      await _open(tester, _today);

      await tester.tap(
        find.bySemanticsIdentifier(SlotIds.daySheetEventAdd).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(find.text('uri /event-edit?date=2026-10-13'), findsOneWidget);
      expect(find.text('extra null'), findsOneWidget);
    });

    testWidgets('empty: 일정이 없으면 빈 문장과 일정 추가, 누르면 그날 event-edit', (
      tester,
    ) async {
      await _open(tester, CalendarDate(2026, 10, 14));

      expect(find.byType(EventRow), findsNothing);
      final empty = tester.widget<EventRowListEmpty>(
        find.byType(EventRowListEmpty),
      );
      expect(empty.message, _ko.daySheetEventEmpty);
      expect(empty.addLabel, _ko.daySheetEventAdd);
      expect(empty.messageIdentifier, SlotIds.daySheetEventEmpty);
      expect(empty.addIdentifier, SlotIds.daySheetEventAdd);

      await tester.tap(find.text(_ko.daySheetEventAdd));
      await tester.pumpAndSettle();
      expect(find.text('uri /event-edit?date=2026-10-14'), findsOneWidget);
    });

    testWidgets('일정을 받지 못하면 빈 문장 대신 오류 한 줄·다시 시도·일정 추가', (tester) async {
      final server = ScheduleTestServer()..offline = true;
      await _open(tester, _today, server: server);

      expect(find.byType(EventRow), findsNothing);
      expect(find.text(_ko.daySheetEventEmpty), findsNothing);
      expect(find.text(_ko.errorOffline), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetEventAdd),
        findsOneWidget,
      );
      expect(find.byType(ErrorState), findsNothing);

      server.offline = false;
      await tester.tap(find.text(_ko.actionRetry));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['엄마 생신', '팀 주간 회의', '요가 수업']);
      expect(find.text(_ko.errorOffline), findsNothing);
    });

    testWidgets('일정 범위를 다시 받는 동안에도 들고 있던 목록을 그대로 보입니다', (tester) async {
      final server = ScheduleTestServer(seed: _shuffledSchedules());
      final harness = await _open(tester, _today, server: server);
      final gate = server.holdNextGet();

      ProviderScope.containerOf(harness.context)
          .invalidate(schedulesInRangeProvider((from: _today, to: _today)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(_rowTitles(tester), ['엄마 생신', '팀 주간 회의', '요가 수업']);
      gate.complete();
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['엄마 생신', '팀 주간 회의', '요가 수업']);
    });

    testWidgets('일기 여부를 묻는 동안 링크 자리를 잡아 두어 높이가 바뀌지 않습니다', (tester) async {
      final answer = Completer<bool>();
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness(
        server: ScheduleTestServer(),
        calendar: () async => _october(),
        diaryExists: (_) => answer.future,
      );
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.app());
      final container = ProviderScope.containerOf(harness.context);
      unawaited(
        container.read(daySheetsProvider).open(harness.context, _today),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      const skeleton = ValueKey('day-sheet.diary.skeleton');
      expect(find.byKey(skeleton), findsOneWidget);
      final reserved = tester.getSize(find.byKey(skeleton)).height;

      answer.complete(false);
      await tester.pumpAndSettle();
      expect(find.byKey(skeleton), findsNothing);
      // 글줄 높이는 글꼴의 반올림만큼(1px 미만) 다를 수 있습니다.
      expect(
        tester.getSize(find.byType(DepthLink)).height,
        closeTo(reserved, 1),
      );
    });

    testWidgets('지난 날에 일기가 있으면 일기 보기 → 그날 diary-view', (tester) async {
      await _open(
        tester,
        CalendarDate(2026, 10, 12),
        diaryExists: (_) async => true,
      );

      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta),
        findsNothing,
      );
      expect(
        tester.widget<DepthLink>(find.byType(DepthLink)).label,
        _ko.daySheetDiaryOpen,
      );
      await tester.tap(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(find.text('uri /diary-view?date=2026-10-12'), findsOneWidget);
    });

    testWidgets('오늘 일기가 없으면 일기 쓰기 → 그날 diary-edit', (tester) async {
      final harness = await _open(tester, _today);

      expect(harness.diaryChecks, [_today]);
      final link = tester.widget<DepthLink>(find.byType(DepthLink));
      expect(link.label, _ko.daySheetDiaryWriteCta);
      expect(link.variant, DepthLinkVariant.navigate);
      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen),
        findsNothing,
      );
      await tester.tap(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(find.text('uri /diary-edit?date=2026-10-13'), findsOneWidget);
    });

    testWidgets('미래 날에는 일기 입구가 없고 일기를 묻지도 않습니다(D49)', (tester) async {
      final harness = await _open(tester, CalendarDate(2026, 10, 20));

      expect(harness.diaryChecks, isEmpty);
      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta),
        findsNothing,
      );
      expect(_rowTitles(tester), ['치과 정기 검진']);
    });

    testWidgets('loading: 달 길흉을 기다리는 동안 skeleton, 오면 내용입니다', (tester) async {
      final pending = Completer<Calendar>();
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness(
        server: ScheduleTestServer(),
        calendar: () => pending.future,
        diaryExists: (_) async => false,
      );
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.app());
      final container = ProviderScope.containerOf(harness.context);
      unawaited(
        container.read(daySheetsProvider).open(harness.context, _today),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.byKey(const ValueKey('screen-state.loading')),
        findsOneWidget,
      );
      expect(find.byType(DayCharacter), findsNothing);

      pending.complete(_october());
      await tester.pumpAndSettle();
      expect(find.byType(DayCharacter), findsOneWidget);
    });

    testWidgets('error: 달 길흉을 받지 못하면 오류 화면, 다시 시도하면 내용입니다', (tester) async {
      var attempts = 0;
      await _open(
        tester,
        _today,
        calendar: () async {
          attempts++;
          if (attempts == 1) {
            throw const OfflineError();
          }
          return _october();
        },
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(DayCharacter), findsNothing);

      await tester.tap(find.text(_ko.actionRetry));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(DayCharacter), findsOneWidget);
    });
  });

  group('daySheetBodyProvider', () {
    test('연결하지 않으면 본문을 만들 때 실패합니다', () {
      final plain = ProviderContainer();
      addTearDown(plain.dispose);
      expect(
        () => plain.read(daySheetsProvider).body(_today),
        throwsUnimplementedError,
      );
    });

    test('app의 override가 실제 본문을 잇습니다', () {
      final wired = ProviderContainer(overrides: daySheetBodyOverrides);
      addTearDown(wired.dispose);
      final body = wired.read(daySheetsProvider).body(_today);
      expect(body, isA<DaySheetBody>());
      expect((body as DaySheetBody).date, _today);
    });
  });

  group('sheetRegistry', () {
    test('day-sheet는 loading·empty·error를 처리하고 IA 출구 넷으로 갑니다', () {
      final spec = sheetRegistry[ScreenIds.daySheet]!;
      expect(spec.handledStates, {'loading', 'empty', 'error'});
      expect(spec.exits, {
        ScreenIds.eventEdit,
        ScreenIds.diaryView,
        ScreenIds.diaryEdit,
        ScreenIds.explainSheet,
      });
    });
  });
}
