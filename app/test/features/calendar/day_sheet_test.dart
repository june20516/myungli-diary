import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/depth_sheet_bodies.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/sheet_registry.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/calendar/fortune_verdict.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/calendar/presentation/day_sheet_body.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';

import '../../support/fonts.dart';
import '../../support/schedule_test_server.dart';
import '../../support/sheet_close.dart';

final _ko = AppLocalizationsKo();

final _today = CalendarDate(2026, 10, 13);

/// member 시나리오의 2026년 10월 달 길흉.
Calendar _october() {
  final fixture = jsonDecode(
    File('fixtures/member/getCalendar__2026-10.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Calendar.fromJson(fixture['body'] as Map<String, dynamic>);
}

/// 사전: 태그 이름은 용어(`day_kind`, `relation`), 뜻은 `score_item` 범주 값 이름입니다.
/// `gwiin_day`·`yongsin_day`는 뜻이 태그 이름과 같아 뜻 줄이 생략됩니다.
const _glossary = GlossaryNames({
  'day_kind': {
    'gwiin_day': '귀인의 날',
    'yongsin_day': '용신의 날',
    'gisin_day': '기신의 날',
    'ordinary_day': '평범한 날',
  },
  'relation': {'branch_hap': '육합', 'chung': '충', 'hyeong': '형'},
  'score_item': {
    'gwiin_day': '귀인의 날',
    'yongsin_day': '용신의 날',
    'hap': '짝이 맞는 날',
    'hyeong': '부딪히는 날',
  },
});

/// 큰 글자 검사용 ja, en 사전: 이름은 짧게, 뜻은 두 줄을 채울 만큼 깁니다.
const _glossaryJa = GlossaryNames({
  'day_kind': {'yongsin_day': '用神の日'},
  'relation': {'branch_hap': '六合', 'hyeong': '刑'},
  'score_item': {
    'hap': '相性のよい二つの支が出会い、物事が穏やかにまとまりやすい日です',
    'hyeong': '支どうしがぶつかり合い、気持ちがささくれやすい日になります',
  },
});

const _glossaryEn = GlossaryNames({
  'day_kind': {'yongsin_day': 'Yongsin Day'},
  'relation': {'branch_hap': 'Harmony', 'hyeong': 'Clash'},
  'score_item': {
    'hap': 'Two branches pair up and things tend to settle down smoothly',
    'hyeong': 'Branches grind against each other and moods get rough',
  },
});

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
    required this.diaries,
    this.textScale = 1,
    this.locale = const Locale('ko'),
    GlossaryNames? glossary,
  }) : glossary = glossary ?? _glossary;

  final GlossaryNames glossary;
  final double textScale;
  final Locale locale;
  final explained = <String>[];

  final ScheduleTestServer server;
  final Future<Calendar> Function() calendar;
  final Future<List<DiarySummary>> Function(CalendarDate date) diaries;

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
      calendarMonthProvider.overrideWithBuild((ref, _) => calendar()),
      diariesOnProvider.overrideWith((ref, date) {
        diaryChecks.add(date);
        return diaries(date);
      }),
      daySheetBodyProvider.overrideWithValue(
        (date) => DaySheetBody(date: date),
      ),
      glossaryProvider.overrideWith((ref) async => glossary),
      explainBodyProvider.overrideWithValue((content, {head, diaryLinkTag}) {
        final term = content as ExplainTerm;
        explained.add(term.termId);
        return Text('풀이 ${term.termId} ${term.origin?.slotId}');
      }),
    ],
    child: MaterialApp.router(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(brightness: Brightness.light, locale: locale),
    ),
  );
}

Future<_Harness> _open(
  WidgetTester tester,
  CalendarDate date, {
  ScheduleTestServer? server,
  Future<Calendar> Function()? calendar,
  Future<List<DiarySummary>> Function(CalendarDate date)? diaries,
  double textScale = 1,
  Locale locale = const Locale('ko'),
  GlossaryNames? glossary,
}) async {
  tester.view
    ..physicalSize = const Size(400, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(
    server: server ?? ScheduleTestServer(seed: _shuffledSchedules()),
    calendar: calendar ?? () async => _october(),
    diaries: diaries ?? (_) async => const [],
    textScale: textScale,
    locale: locale,
    glossary: glossary,
  );
  addTearDown(harness.router.dispose);
  await tester.pumpWidget(harness.app());
  final container = ProviderScope.containerOf(harness.context);
  unawaited(container.read(daySheetsProvider).open(harness.context, date));
  await tester.pumpAndSettle();
  return harness;
}

/// [date]에 쓴 일기 [count]편(작성 순, id `d<date>-<순번>`).
List<DiarySummary> _diaries(CalendarDate date, int count) => [
  for (var i = 1; i <= count; i++)
    DiarySummary(
      id: 'd${date.toIso()}-$i',
      date: date.toIso(),
      createdAt: DateTime.utc(date.year, date.month, date.day, 9, i),
      excerpt: '$i번째 일기',
      featuredTags: const [],
    ),
];

/// 쓰기 버튼(`day-sheet.diary.write-cta`).
PrimaryButton _writeButton(WidgetTester tester) => tester.widget<PrimaryButton>(
  find.ancestor(
    of: find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta),
    matching: find.byType(PrimaryButton),
  ),
);

/// 날의 성격 태그(`day-sheet.character.label` 안).
final Finder _dayKindTag = find.descendant(
  of: find.byKey(const ValueKey(SlotIds.daySheetCharacterLabel)),
  matching: find.byType(HanjaTag),
);

List<String> _rowTitles(WidgetTester tester) => [
  for (final row in tester.widgetList<EventRow>(find.byType(EventRow)))
    row.title,
];

void main() {
  setUpAll(loadBundledFonts);

  group('DaySheets.open', () {
    testWidgets('화면 id가 Key·Semantics에 붙고 시트 이름은 그 날짜입니다', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, CalendarDate(2026, 10, 12));

      expect(find.byKey(const Key(ScreenIds.daySheet)), findsOneWidget);
      expect(find.bySemanticsIdentifier(ScreenIds.daySheet), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('10월 12일 월요일')), findsWidgets);
      semantics.dispose();
    });

    testWidgets('처음부터 full 시트로 열립니다(긴 본문도 위 간격까지)', (tester) async {
      final harness = await _open(tester, CalendarDate(2026, 10, 12));
      // full은 내용 높이를 따르다 위 간격까지 올라갑니다(half 60%에서 멈추지 않음).
      await tapSheetScrim(tester);
      await tester.pumpAndSettle();

      final tall = DaySheets(body: (_) => const SizedBox(height: 4000));
      unawaited(tall.open(harness.context, _today));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(MyungliSheetFrame)).height,
        closeTo(900 - sheetFullTopGap, 0.01),
      );
    });
  });

  group('DaySheetBody', () {
    testWidgets('날짜 머리는 날짜와 음력만이고 일진은 없습니다', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 12));

      final header = tester.widget<DateHeader>(find.byType(DateHeader));
      expect(header.solar, '10월 12일 월요일');
      expect(header.lunar, _ko.daySheetDateLunar(9, 2));
      expect(header.iljin, isNull);
    });

    testWidgets('날의 성격은 날짜 머리 아래 space.12의 hanja-tag emphasis입니다', (
      tester,
    ) async {
      await _open(tester, CalendarDate(2026, 10, 12));

      final label = find.byKey(const ValueKey(SlotIds.daySheetCharacterLabel));
      final tag = tester.widget<HanjaTag>(
        find.descendant(of: label, matching: find.byType(HanjaTag)),
      );
      expect(tag.variant, HanjaTagVariant.emphasis);
      expect(tag.label, _ko.dayKindGwiinDay);
      expect(tag.glyph, '貴');
      expect(
        tester.getTopLeft(label).dy -
            tester.getBottomLeft(find.byType(DateHeader)).dy,
        Space.s12,
      );
    });

    testWidgets('이유 문장은 없습니다(용어 칩도 없음)', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 12));

      expect(find.byType(TermToken), findsNothing);
      expect(find.byType(SentenceBlock), findsNothing);
    });

    testWidgets('날의 성격 태그를 누르면 그 날의 성격 뜻 시트입니다', (tester) async {
      final harness = await _open(tester, CalendarDate(2026, 10, 12));

      await tester.tap(find.byType(HanjaTag).first);
      await tester.pumpAndSettle();

      expect(harness.explained.toSet(), {'day_kind.${DayKind.gwiinDay.value}'});
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
    });

    testWidgets('섹션 순서: 날짜, 성격, 길흉판정, 일정, 일기', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 12));

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final tops = [
        top(find.byType(DateHeader)),
        top(find.byKey(const ValueKey(SlotIds.daySheetCharacterLabel))),
        top(find.text(_ko.daySheetVerdictTitle)),
        top(find.byType(FortuneVerdict)),
        top(find.text(_ko.todayEventTitle)),
        top(find.text(_ko.daySheetDiaryOpen)),
        top(find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta)),
      ];
      expect(tops, [...tops]..sort());
      // 섹션 사이는 space.32, 제목과 내용 사이는 space.12입니다.
      expect(
        top(find.byType(FortuneVerdict)) -
            tester.getBottomLeft(find.text(_ko.daySheetVerdictTitle)).dy,
        Space.s12,
      );
    });

    testWidgets('길흉판정: 태그 이름은 용어 이름, 뜻이 이름과 같으면 생략합니다', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 13));

      final verdict = tester.widget<FortuneVerdict>(
        find.byType(FortuneVerdict),
      );
      expect(verdict.score, 2);
      final rows = tester.widgetList<ScoreRow>(find.byType(ScoreRow)).toList();
      // 더함 먼저, 뺌 다음: 용신의 날(뜻 생략), 합, 형.
      expect(rows.map((row) => row.name), ['용신의 날', '육합', '형']);
      expect(rows.map((row) => row.meaning), ['', '짝이 맞는 날', '부딪히는 날']);
      expect(rows.map((row) => row.score), [2, 1, -1]);
    });

    testWidgets('길흉판정 태그를 누르면 매핑된 용어의 뜻 시트입니다', (tester) async {
      final harness = await _open(tester, CalendarDate(2026, 10, 13));

      for (final name in ['육합', '형']) {
        await tester.tap(find.widgetWithText(HanjaTag, name));
        await tester.pumpAndSettle();
        await closeSheet(tester, find.byKey(const Key(ScreenIds.explainSheet)));
      }

      expect(harness.explained.toSet(), {
        'relation.branch_hap',
        'relation.hyeong',
      });
    });

    testWidgets('scoreItems가 비면 막대와 이름만 그리고 나머지는 같은 자리입니다', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 20));

      expect(find.byType(FortuneVerdict), findsOneWidget);
      expect(find.byKey(FortuneVerdict.trackKey), findsOneWidget);
      expect(find.byType(ScoreRow), findsNothing);
      expect(find.text(_ko.todayEventTitle), findsOneWidget);
    });

    testWidgets('사전에 이름이 없는 내역은 줄을 빼고 한 번만 기록합니다(A112)', (tester) async {
      final harness = await _open(
        tester,
        CalendarDate(2026, 10, 12),
        glossary: const GlossaryNames({
          'day_kind': {'gwiin_day': '귀인의 날'},
        }),
      );
      await tester.pumpAndSettle();

      final rows = tester.widgetList<ScoreRow>(find.byType(ScoreRow)).toList();
      expect(rows.map((row) => row.name), ['귀인의 날']);
      expect(harness.crash.errors, hasLength(1));
      // 다시 그려도 거듭 기록하지 않습니다.
      await tester.pump(const Duration(seconds: 1));
      expect(harness.crash.errors, hasLength(1));
    });

    for (final locale in [const Locale('ja'), const Locale('en')]) {
      for (final scale in [1.3, 2.0]) {
        testWidgets(
          '${locale.languageCode} textScale $scale: 내역 뜻은 두 줄 안에서 넘치지 않습니다',
          (tester) async {
            await _open(
              tester,
              CalendarDate(2026, 10, 13),
              textScale: scale,
              locale: locale,
              glossary: locale.languageCode == 'ja' ? _glossaryJa : _glossaryEn,
            );

            expect(tester.takeException(), isNull);
            for (final meaning in tester.widgetList<Text>(
              find.byKey(ScoreRow.meaningKey),
            )) {
              expect(meaning.maxLines, lessThanOrEqualTo(2));
            }
          },
        );
      }
    }

    testWidgets('시트에는 광고 배너가 없습니다(D53)', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 13));

      expect(find.byType(AdBanner), findsNothing);
      expect(find.byType(AdBannerFrame), findsNothing);
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

    testWidgets('empty: 일정이 없으면 빈 문장만, 추가는 섹션 머리 +입니다', (tester) async {
      await _open(tester, CalendarDate(2026, 10, 14));

      expect(find.byType(EventRow), findsNothing);
      final empty = tester.widget<EventRowListEmpty>(
        find.byType(EventRowListEmpty),
      );
      expect(empty.message, _ko.daySheetEventEmpty);
      expect(empty.messageIdentifier, SlotIds.daySheetEventEmpty);
      // 빈 문장 아래 별도 추가 버튼은 없습니다(V85).
      expect(
        find.widgetWithText(PrimaryButton, _ko.daySheetEventAdd),
        findsNothing,
      );

      await tester.tap(
        find.bySemanticsIdentifier(SlotIds.daySheetEventAdd).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('uri /event-edit?date=2026-10-14'), findsOneWidget);
    });

    testWidgets('일정 섹션 머리: 제목 "일정"과 오른쪽 + 하나', (tester) async {
      await _open(tester, _today);

      expect(find.text(_ko.todayEventTitle), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetEventAdd),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PrimaryButton, _ko.daySheetEventAdd),
        findsNothing,
      );
    });

    testWidgets('일정을 받지 못하면 빈 문장 대신 오류 한 줄과 다시 시도(추가는 머리 +)', (tester) async {
      final server = ScheduleTestServer()..offline = true;
      await _open(tester, _today, server: server);

      expect(find.byType(EventRow), findsNothing);
      expect(find.text(_ko.daySheetEventEmpty), findsNothing);
      expect(find.byType(EventRowListFailed), findsOneWidget);
      expect(find.text(_ko.errorOffline), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, _ko.actionRetry),
        findsOneWidget,
      );
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

    testWidgets('loading: 그날 일기를 받는 동안 입구 자리에 skeleton, 오면 버튼', (tester) async {
      final answer = Completer<List<DiarySummary>>();
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness(
        server: ScheduleTestServer(),
        calendar: () async => _october(),
        diaries: (_) => answer.future,
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
      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta),
        findsNothing,
      );

      answer.complete(const []);
      await tester.pumpAndSettle();
      expect(find.byKey(skeleton), findsNothing);
      expect(_writeButton(tester).label, _ko.daySheetDiaryWriteCta('10월 13일'));
    });

    testWidgets('지난 날 0편: 일기 제목 아래 줄 없이 쓰기 버튼만 → 그날 새 일기', (tester) async {
      final harness = await _open(tester, CalendarDate(2026, 10, 12));

      expect(harness.diaryChecks, [CalendarDate(2026, 10, 12)]);
      // 쓴 일기가 없어도 섹션 제목은 보입니다.
      expect(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen),
        findsOneWidget,
      );
      expect(find.byType(DiaryEntryLine), findsNothing);
      expect(find.byKey(DiaryEntries.cardKey), findsNothing);
      // 쓰기는 실행하는 동작이라 filled 버튼입니다(V37).
      final button = _writeButton(tester);
      expect(button.label, _ko.daySheetDiaryWriteCta('10월 12일'));
      expect(button.variant, PrimaryButtonVariant.filled);
      await tester.tap(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(find.text('uri /diary-edit?date=2026-10-12'), findsOneWidget);
    });

    testWidgets('3편: 섹션 제목 아래 작성 순 줄 3개와 이날 새 일기 쓰기', (tester) async {
      final day = CalendarDate(2026, 10, 12);
      await _open(tester, day, diaries: (date) async => _diaries(date, 3));

      final head = find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen);
      expect(head, findsOneWidget);
      expect(
        find.descendant(of: head, matching: find.text(_ko.daySheetDiaryOpen)),
        findsOneWidget,
      );
      final lines = tester
          .widgetList<DiaryEntryLine>(find.byType(DiaryEntryLine))
          .toList();
      expect(
        [for (final line in lines) line.excerpt],
        ['1번째 일기', '2번째 일기', '3번째 일기'],
        reason: '작성 순 그대로',
      );
      // 줄만 있고 날짜 열·태그 칩은 없습니다(그날 시트 모양).
      expect(find.byType(DiaryRow), findsNothing);
      expect(find.byKey(DiaryRow.dateColumnKey), findsNothing);
      expect(
        _writeButton(tester).label,
        _ko.daySheetDiaryWriteCtaWritten('10월 12일'),
      );
      expect(_writeButton(tester).onPressed, isNotNull);

      // 줄은 머리와 버튼 사이에 놓입니다.
      final headTop = tester.getTopLeft(head).dy;
      final rowTop = tester.getTopLeft(find.byType(DiaryEntryLine).first).dy;
      final buttonTop = tester
          .getTopLeft(find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta))
          .dy;
      expect(headTop, lessThan(rowTop));
      expect(rowTop, lessThan(buttonTop));

      await tester.ensureVisible(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('uri /diary-edit?date=2026-10-12'), findsOneWidget);
    });

    testWidgets('일기 섹션 제목은 링크가 아니라 글자입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(
        tester,
        CalendarDate(2026, 10, 12),
        diaries: (date) async => _diaries(date, 2),
      );
      final data = tester
          .getSemantics(find.text(_ko.daySheetDiaryOpen))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.identifier, SlotIds.daySheetDiaryOpen);
      handle.dispose();
    });

    testWidgets('일기 줄을 누르면 그 일기의 diary-view', (tester) async {
      await _open(
        tester,
        CalendarDate(2026, 10, 12),
        diaries: (date) async => _diaries(date, 2),
      );
      await tester.ensureVisible(find.byType(DiaryEntryLine).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DiaryEntryLine).at(1));
      await tester.pumpAndSettle();
      expect(find.text('uri /diary-view?id=d2026-10-12-2'), findsOneWidget);
    });

    for (final count in [10, 11]) {
      testWidgets('$count편이면 쓰기 버튼은 다 채웠다는 문구로 꺼집니다', (tester) async {
        await _open(
          tester,
          _today,
          diaries: (date) async => _diaries(date, count),
        );
        final button = _writeButton(tester);
        expect(button.label, _ko.daySheetDiaryWriteCtaFull);
        expect(button.onPressed, isNull);
        expect(
          find.descendant(
            of: find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen),
            matching: find.text(_ko.daySheetDiaryOpen),
          ),
          findsOneWidget,
        );
        expect(find.byType(DiaryEntryLine), findsNWidgets(count));
      });
    }

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
        diaries: (_) async => const [],
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
      expect(_dayKindTag, findsNothing);

      pending.complete(_october());
      await tester.pumpAndSettle();
      expect(_dayKindTag, findsOneWidget);
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
      expect(_dayKindTag, findsNothing);

      await tester.tap(find.text(_ko.actionRetry));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(_dayKindTag, findsOneWidget);
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
