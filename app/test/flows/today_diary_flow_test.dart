import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/features/diary/presentation/diary_page_list.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();
final _today = CalendarDate(2026, 10, 13);

Finder _screen(String id) => find.byKey(ValueKey(id));

String _locationOf(WidgetTester tester, String screenId) =>
    GoRouterState.of(tester.element(_screen(screenId).last)).uri.toString();

GuideQuestionCard _guide(WidgetTester tester) =>
    tester.widget<GuideQuestionCard>(find.byType(GuideQuestionCard));

/// 오늘 가이드 카드로 새 일기를 열어 [body]로 저장하고, 보기에서 뒤로 오늘에 돌아옵니다.
Future<void> _writeFromToday(WidgetTester tester, String body) async {
  final action = find.bySemanticsIdentifier(SlotIds.todayGuideCta);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await pumpUntil(tester, () => find.byType(TextField).evaluate().isNotEmpty);
  await settleWithIo(tester);
  expect(
    _locationOf(tester, ScreenIds.diaryEdit),
    '/diary-edit?date=2026-10-13',
  );
  expect(
    tester.widget<TextField>(find.byType(TextField)).controller!.text,
    isEmpty,
    reason: '언제나 빈 새 일기',
  );

  await tester.enterText(find.byType(TextField), body);
  await tester.pump();
  await tester.tap(find.text(_ko.diaryEditSave));
  await pumpUntil(
    tester,
    () => find.text(_ko.diaryEditSavedTags).evaluate().isNotEmpty,
  );
  await pumpUntilScreen(tester, ScreenIds.diaryView);
  await pumpUntil(
    tester,
    () => find.textContaining(body).evaluate().isNotEmpty,
  );
  await settleWithIo(tester, allowOngoing: true);
  // toast가 사라질 때까지 둡니다.
  await tester.pump(const Duration(seconds: 3));
  await settleWithIo(tester);

  await tester.tap(find.byKey(const ValueKey('app-bar.back')).last);
  await settleWithIo(tester);
  expect(_screen(ScreenIds.diaryView), findsNothing);
}

void main() {
  testWidgets('오늘 한 편 쓰고 돌아오면 줄 1개, 한 편 더 쓰면 줄 2개와 달력 도장', (tester) async {
    covers(const Covers(exits: ['today>diary-edit', 'today>diary-view']));
    await pumpApp(tester, scenario: 'member');
    await pumpUntil(
      tester,
      () => find.byType(DayCharacter).evaluate().isNotEmpty,
    );
    expect(_guide(tester).actionLabel, _ko.todayGuideCta);
    expect(find.byType(DiarySummaryRow), findsNothing);

    await _writeFromToday(tester, '아침에 산책을 했다.');
    await pumpUntil(
      tester,
      () => find.byType(DiarySummaryRow).evaluate().length == 1,
    );
    expect(_guide(tester).state, GuideQuestionState.after);
    expect(_guide(tester).actionLabel, _ko.todayGuideCtaWritten);

    await _writeFromToday(tester, '저녁에 책을 읽었다.');
    await pumpUntil(
      tester,
      () => find.byType(DiarySummaryRow).evaluate().length == 2,
    );
    final rows = tester
        .widgetList<DiarySummaryRow>(find.byType(DiarySummaryRow))
        .toList();
    // 작성 순입니다.
    expect(rows.first.summary.excerpt, startsWith('아침에'));
    expect(rows.last.summary.excerpt, startsWith('저녁에'));

    // 두 번째 줄 → 그 일기의 diary-view.
    await tester.ensureVisible(find.byType(DiarySummaryRow).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DiarySummaryRow).last);
    await pumpUntil(
      tester,
      () => find.textContaining('저녁에 책을').evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
    expect(
      _locationOf(tester, ScreenIds.diaryView),
      '/diary-view?id=${rows.last.summary.id}',
    );
    await tester.tap(find.byKey(const ValueKey('app-bar.back')).last);
    await settleWithIo(tester);

    // 달력의 오늘 칸에 도장이 찍힙니다.
    await tester.tap(find.byKey(const ValueKey('tab-bar.tab.1')));
    await settleWithIo(tester);
    final todayCell = tester.widget<DayCell>(
      find.descendant(
        of: find.byKey(CalendarMonthView.cellKey(_today)),
        matching: find.byType(DayCell),
      ),
    );
    expect(todayCell.data.diaryWritten, isTrue);
  });
}
