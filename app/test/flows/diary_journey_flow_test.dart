import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/features/diary/presentation/diary_list_screen.dart';
import 'package:myungli_diary/features/diary/presentation/diary_view_screen.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

/// 일기가 없던 날. 이 흐름에서 쓰고 지웁니다.
final _day = CalendarDate(2026, 10, 10);

Finder _screen(String id) => find.byKey(ValueKey(id));

/// [date] 줄([DiaryRow]).
Finder _rowOf(CalendarDate date) =>
    find.byWidgetPredicate((w) => w is DiaryRow && w.date == date);

String _locationOf(WidgetTester tester, String screenId) =>
    GoRouterState.of(tester.element(_screen(screenId).last)).uri.toString();

/// 맨 위 화면에서 뒤로 갑니다.
Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-bar.back')).last);
  await settleWithIo(tester);
}

void main() {
  testWidgets('목록 → 날짜 골라 쓰기 → 저장 → 보기 → 태그 모아보기 → 보기 → 지우기 → 목록', (
    tester,
  ) async {
    await pumpApp(tester, scenario: 'member');
    await tester.tap(find.byKey(const ValueKey('tab-bar.tab.2')));
    await settleWithIo(tester);
    expect(find.byType(DiaryRow), findsNWidgets(4));
    expect(_rowOf(_day), findsNothing);

    // 날짜 골라 쓰기: 일기 없는 날 → 쓰기 화면.
    await tester.tap(find.byKey(DiaryListScreen.pickDateKey));
    await settleWithIo(tester);
    await tester.tap(find.byKey(CalendarMonthView.cellKey(_day)));
    await tester.pump();
    final confirm = find.text('10월 10일 일기');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await pumpUntil(tester, () => find.byType(TextField).evaluate().isNotEmpty);
    await settleWithIo(tester);
    expect(
      _locationOf(tester, ScreenIds.diaryEdit),
      '/diary-edit?date=2026-10-10',
    );

    // 쓰고 저장 → 저장 순간 뒤 그날 보기로 바뀝니다.
    await tester.enterText(find.byType(TextField), '비가 그친 오후에 산책을 했다.');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    await pumpUntil(
      tester,
      () => find.text(_ko.diaryEditSavedTags).evaluate().isNotEmpty,
    );
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await pumpUntil(
      tester,
      () => find.textContaining('비가 그친 오후').evaluate().isNotEmpty,
    );
    await settleWithIo(tester, allowOngoing: true);
    expect(_screen(ScreenIds.diaryEdit), findsNothing);
    expect(
      _locationOf(tester, ScreenIds.diaryView),
      '/diary-view?date=2026-10-10',
    );

    // 태그 칩 → 그 태그 모아보기에 방금 쓴 날이 있습니다.
    await tester.tap(
      find
          .descendant(
            of: _screen(ScreenIds.diaryView),
            matching: find.byType(TagChip),
          )
          .first,
    );
    await pumpUntilScreen(tester, ScreenIds.tagDiary);
    await pumpUntil(tester, () => _rowOf(_day).evaluate().isNotEmpty);
    await settleWithIo(tester);
    // toast가 사라질 때까지 둡니다.
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);

    // 그 줄 → 보기 → 지우기.
    await tester.tap(_rowOf(_day));
    await pumpUntil(
      tester,
      () => find.byKey(DiaryViewScreen.deleteKey).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
    await tester.tap(find.byKey(DiaryViewScreen.deleteKey));
    await settleWithIo(tester);
    await tester.tap(find.text(_ko.diaryViewDeleteConfirmDelete));
    await settleWithIo(tester, allowOngoing: true);
    expect(find.text(_ko.diaryViewDeleted), findsOneWidget);

    // 태그 모아보기로 돌아오고, 지운 날은 목록에서 빠집니다.
    await pumpUntil(tester, () => _rowOf(_day).evaluate().isEmpty);
    expect(_screen(ScreenIds.tagDiary), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);

    // 그 아래 쌓인 보기는 지운 일기라 안내만 남고, 목록에서도 빠졌습니다.
    await _back(tester);
    expect(find.text(_ko.errorDiaryNotFound), findsOneWidget);
    await _back(tester);
    await pumpUntil(tester, () => find.byType(DiaryRow).evaluate().length == 4);
    expect(_screen(ScreenIds.diaryList), findsOneWidget);
    expect(_rowOf(_day), findsNothing);
  });
}
