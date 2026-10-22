import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/input/month_date_picker.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/features/diary/application/diary_pages.dart';
import 'package:myungli_diary/features/diary/presentation/diary_list_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';

final _ko = AppLocalizationsKo();

/// [offline]이면 모든 요청을 연결 오류로 끊고, [emptyDiaries]면 일기 목록을 빈 목록으로 답합니다.
final class _Network extends Interceptor {
  bool offline = false;
  bool emptyDiaries = false;

  /// 하루 범위(`from`==`to`) 일기 목록을 날짜마다 물은 횟수.
  final dayQueries = <String, int>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: '오프라인'),
        true,
      );
      return;
    }
    final from = options.queryParameters['from'];
    if (options.path == '/v1/diaries' &&
        from != null &&
        from == options.queryParameters['to']) {
      dayQueries.update('$from', (count) => count + 1, ifAbsent: () => 1);
    }
    if (emptyDiaries && options.path == '/v1/diaries') {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: {'items': <Object>[]},
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/json'],
          }),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

/// member로 앱을 띄우고 일기 탭으로 갑니다.
Future<ProviderContainer> _openDiaryList(
  WidgetTester tester, {
  _Network? network,
  List<Override> overrides = const [],
}) async {
  final container = await pumpApp(
    tester,
    scenario: 'member',
    overrides: overrides,
  );
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  await tester.tap(find.byKey(const ValueKey('tab-bar.tab.2')));
  await settleWithIo(tester);
  expect(find.byKey(const ValueKey(ScreenIds.diaryList)), findsOneWidget);
  return container;
}

/// 열린 [screenId] 화면의 경로(`GoRouterState.uri`).
String _locationOf(WidgetTester tester, String screenId) =>
    GoRouterState.of(tester.element(find.byKey(ValueKey(screenId)).last)).uri
        .toString();

List<CalendarDate> _rowDates(WidgetTester tester) => [
  for (final row in tester.widgetList<DiaryRow>(find.byType(DiaryRow)))
    row.date,
];

void main() {
  testWidgets('member: 달 머리 아래 일기 줄(날짜 내림차순)과 배지·대표 태그', (tester) async {
    covers(const Covers(decisions: ['D47', 'D48']));
    await _openDiaryList(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.diaryListBarTitle,
      _ko.diaryListBarTitle,
    );
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(_rowDates(tester), [
      CalendarDate(2026, 10, 12),
      CalendarDate(2026, 10, 8),
      CalendarDate(2026, 10, 5),
      CalendarDate(2026, 10, 2),
    ]);
    final first = tester.widget<DiaryRow>(find.byType(DiaryRow).first);
    expect(first.character, isA<DayCharacterVariant>());
    expect(first.tag!.name, '천을귀인');
    expect(first.tag!.variant, TagChipVariant.good);
    expect(tester.widget<DiaryRow>(find.byType(DiaryRow).last).isLast, isTrue);
  });

  testWidgets('줄을 누르면 그 줄 일기의 diary-view, 태그 칩을 누르면 tag-diary', (tester) async {
    covers(
      const Covers(exits: ['diary-list>diary-view', 'diary-list>tag-diary']),
    );
    final container = await _openDiaryList(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(DiaryRow).at(1),
        matching: find.byKey(DiaryRow.cardKey),
      ),
    );
    await settleWithIo(tester);
    expect(
      _locationOf(tester, ScreenIds.diaryView),
      '/diary-view?id=7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a002',
    );

    container.read(routerProvider).pop();
    await settleWithIo(tester);
    await tester.tap(find.byType(TagChip).first);
    await settleWithIo(tester);
    expect(
      _locationOf(tester, ScreenIds.tagDiary),
      '/tag-diary?tag=cheoneul_gwiin',
    );
  });

  testWidgets('empty: 쓴 일기가 없으면 안내와 날짜 골라 쓰기', (tester) async {
    covers(const Covers(states: ['diary-list:empty']));
    final container = await _openDiaryList(
      tester,
      network: _Network()..emptyDiaries = true,
    );
    container.invalidate(diaryPagesProvider(null));
    await settleWithIo(tester);
    final empty = tester.widget<EmptyState>(find.byType(EmptyState));
    expect(empty.body, _ko.diaryListEmptyBody);
    expect(empty.action!.label, _ko.diaryListPickDateCta);
  });

  testWidgets('error: 받은 적 없이 오프라인이면 오류 화면, 다시 시도하면 목록', (tester) async {
    covers(const Covers(states: ['diary-list:error', 'diary-list:loading']));
    final network = _Network()..offline = true;
    await _openDiaryList(tester, network: network);
    expect(find.byType(ErrorState), findsOneWidget);
    network.offline = false;
    await tester.tap(find.text(_ko.actionRetry));
    await settleWithIo(tester);
    expect(find.byType(DiaryRow), findsNWidgets(4));
  });

  testWidgets('offline: 받아 둔 목록이 있으면 그대로 보이고 배너', (tester) async {
    covers(const Covers(states: ['diary-list:offline']));
    final network = _Network();
    await _openDiaryList(tester, network: network);
    network.offline = true;
    // 다른 탭에 갔다가 돌아오면 다시 묻습니다.
    await tester.tap(find.byKey(const ValueKey('tab-bar.tab.0')));
    await settleWithIo(tester);
    await tester.tap(find.byKey(const ValueKey('tab-bar.tab.2')));
    await settleWithIo(tester);
    expect(find.byType(DiaryRow), findsNWidgets(4));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is NoticeBanner &&
            w.variant == NoticeBannerVariant.offline &&
            w.present,
      ),
      findsOneWidget,
    );
  });

  testWidgets('끝까지 내리면 다음 쪽을 이어 받습니다', (tester) async {
    await _openDiaryList(
      tester,
      overrides: [diaryPageSizeProvider.overrideWithValue(2)],
    );
    await settleWithIo(tester);
    expect(_rowDates(tester), hasLength(4));
  });

  testWidgets('날짜 골라 쓰기: 미래는 막고, 이미 쓴 날도 그날 새 일기', (tester) async {
    covers(const Covers(exits: ['diary-list>diary-edit'], decisions: ['D49']));
    final container = await _openDiaryList(tester);
    await tester.tap(find.byKey(DiaryListScreen.pickDateKey));
    await settleWithIo(tester);
    final picker = tester.widget<MonthDatePicker>(find.byType(MonthDatePicker));
    expect(picker.today, CalendarDate(2026, 10, 13));
    expect(picker.markedDates, contains(CalendarDate(2026, 10, 12)));
    final todayConfirm = find.text(_ko.diaryListPickDateConfirm('10월 13일'));
    expect(todayConfirm, findsOneWidget);
    expect(
      find.bySemanticsIdentifier(SlotIds.diaryListPickDateConfirm),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(CalendarMonthView.cellKey(CalendarDate(2026, 10, 20))),
    );
    await tester.pump();
    expect(todayConfirm, findsOneWidget, reason: '미래 날짜는 막힘');

    await tester.ensureVisible(todayConfirm);
    await tester.pumpAndSettle();
    await tester.tap(todayConfirm);
    await settleWithIo(tester);
    expect(
      _locationOf(tester, ScreenIds.diaryEdit),
      '/diary-edit?date=2026-10-13',
    );

    container.read(routerProvider).pop();
    await settleWithIo(tester);
    await tester.tap(find.byKey(DiaryListScreen.pickDateKey));
    await settleWithIo(tester);
    await tester.tap(
      find.byKey(CalendarMonthView.cellKey(CalendarDate(2026, 10, 12))),
    );
    await settleWithIo(tester);
    final writtenConfirm = find.text(_ko.diaryListPickDateConfirm('10월 12일'));
    await tester.ensureVisible(writtenConfirm);
    await tester.pumpAndSettle();
    await tester.tap(writtenConfirm);
    await settleWithIo(tester);
    expect(
      _locationOf(tester, ScreenIds.diaryEdit),
      '/diary-edit?date=2026-10-12',
    );
  });

  testWidgets('날짜 골라 쓰기: 시트가 열린 동안 다시 고른 날은 그날 일기를 다시 묻지 않습니다', (tester) async {
    final network = _Network();
    await _openDiaryList(tester, network: network);
    await tester.tap(find.byKey(DiaryListScreen.pickDateKey));
    await settleWithIo(tester);
    // 오늘(13일)은 뒤의 오늘 화면이 이미 붙잡고 있어 지난 두 날로 봅니다.
    for (final day in [12, 8, 12, 8]) {
      await tester.tap(
        find.byKey(CalendarMonthView.cellKey(CalendarDate(2026, 10, day))),
      );
      await settleWithIo(tester);
    }
    expect(network.dayQueries['2026-10-12'], 1);
    expect(network.dayQueries['2026-10-08'], 1);
  });

  testWidgets('날짜 골라 쓰기: 10편인 날은 다 채웠다는 문구로 버튼이 꺼집니다', (tester) async {
    await pumpApp(tester, scenario: 'diary-day-full');
    await tester.tap(find.byKey(const ValueKey('tab-bar.tab.2')));
    await settleWithIo(tester);
    await tester.tap(find.byKey(DiaryListScreen.pickDateKey));
    await settleWithIo(tester);

    final confirm = tester.widget<PrimaryButton>(
      find.ancestor(
        of: find.bySemanticsIdentifier(SlotIds.diaryListPickDateConfirm),
        matching: find.byType(PrimaryButton),
      ),
    );
    expect(confirm.label, _ko.diaryListPickDateConfirmFull);
    expect(confirm.onPressed, isNull);
    expect(
      tester.widget<MonthDatePicker>(find.byType(MonthDatePicker)).onConfirm,
      isNull,
    );

    // 다른 날을 고르면 다시 쓸 수 있습니다.
    await tester.tap(
      find.byKey(CalendarMonthView.cellKey(CalendarDate(2026, 10, 12))),
    );
    await settleWithIo(tester);
    expect(find.text(_ko.diaryListPickDateConfirm('10월 12일')), findsOneWidget);
    expect(
      tester.widget<MonthDatePicker>(find.byType(MonthDatePicker)).onConfirm,
      isNotNull,
    );
  });
}
