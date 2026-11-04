import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    show Finder, expect, find, findsNothing, findsOneWidget;
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/features/diary/presentation/diary_list_screen.dart';
import 'package:myungli_diary/features/diary/presentation/diary_view_screen.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';
import 'support/e2e_dates.dart';

/// 쓸 날이 오늘보다 며칠 앞인지입니다. fake의 member는 이날에 일기가 없고(2026-10-10), staging 계정은
/// 일기가 하나도 없습니다. 이 흐름에서 쓰고 지웁니다.
const _daysBeforeToday = 3;

/// 새 일기 본문입니다.
const _body = '비가 그친 오후에 산책을 했다.';

/// [date] 줄([DiaryRow]).
Finder _rowOf(CalendarDate date) =>
    find.byWidgetPredicate((w) => w is DiaryRow && w.date == date);

/// [done]이 참이 될 때까지 프레임을 돌립니다(대역 서버 응답·화면 움직임을 기다림).
Future<void> _waitUntil(
  PatrolIntegrationTester $,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('$timeout 안에 조건을 만족하지 못했습니다');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  patrolTest('member: 날짜 골라 쓰고 저장 → 보기 → 태그 모아보기 → 다시 보기에서 지웁니다', ($) async {
    covers(
      const Covers(
        exits: [
          'diary-list>diary-edit',
          'diary-edit>diary-view',
          'diary-view>tag-diary',
          'tag-diary>diary-view',
        ],
        states: ['diary-list:loading', 'diary-edit:loading'],
        decisions: ['D49'],
      ),
    );
    final container = await launchApp(
      $,
      flow: 'diary',
      scenario: 'member',
      deviceLocale: const Locale('ko', 'KR'),
    );
    await waitForScreen($, ScreenIds.today);

    // 쓸 날은 앱이 쓰는 오늘의 3일 전입니다(fake는 10월 10일, staging은 기기의 실제 오늘 기준).
    final today = e2eToday(container);
    final day = daysBefore(today, _daysBeforeToday);

    // 일기 탭: 고를 날은 아직 없음. fake의 member는 쓴 일기가 넷입니다(staging 계정은 없음).
    await $(find.byKey(const ValueKey('tab-bar.tab.2'))).tap();
    await expectScreen($, ScreenIds.diaryList);
    if (e2eMode == E2eMode.fake) {
      await _waitUntil($, () => find.byType(DiaryRow).evaluate().length == 4);
    }
    expect(_rowOf(day), findsNothing);
    final listElement = $.tester.element(
      find.byKey(const ValueKey(ScreenIds.diaryList)),
    );
    final l10n = AppLocalizations.of(listElement);
    final locale = Localizations.localeOf(listElement).toString();

    // 날짜 골라 쓰기 → 그날 쓰기 화면. 3일 전이 지난 달이면 날짜 고르기에서 이전 달로 넘깁니다.
    await $(find.byKey(DiaryListScreen.pickDateKey)).tap();
    for (var i = 0; i < previousMonthTaps(today, day); i++) {
      await $(find.byKey(CalendarMonthView.prevKey)).tap();
      await $.pumpAndTrySettle();
    }
    await $(find.byKey(CalendarMonthView.cellKey(day))).tap();
    final confirm = find.text(
      l10n.diaryListPickDateConfirm(pickDateLabel(day, locale)),
    );
    await $(confirm).scrollTo();
    await $(confirm).tap();
    await expectScreen($, ScreenIds.diaryEdit);

    // 쓰고 저장 → 저장 순간 뒤 그날 보기.
    await $(find.byType(EditableText)).enterText(_body);
    await $(find.text(l10n.diaryEditSave)).tap();
    await _waitUntil(
      $,
      () =>
          find.textContaining(_body).evaluate().isNotEmpty &&
          find.byKey(const ValueKey(ScreenIds.diaryEdit)).evaluate().isEmpty,
    );
    await expectScreen($, ScreenIds.diaryView);

    // 태그 칩 → 태그 모아보기에 방금 쓴 날.
    await $(
      find
          .descendant(
            of: find.byKey(const ValueKey(ScreenIds.diaryView)),
            matching: find.byType(TagChip),
          )
          .first,
    ).tap();
    await expectScreen($, ScreenIds.tagDiary);
    await _waitUntil($, () => _rowOf(day).evaluate().isNotEmpty);

    // 그 줄 → 보기 → 지우기 → 확인 창에서 지우기.
    await $(_rowOf(day)).tap();
    await waitForScreen($, ScreenIds.diaryView);
    await _waitUntil(
      $,
      () => find.byKey(DiaryViewScreen.deleteKey).evaluate().isNotEmpty,
    );
    await $(find.byKey(DiaryViewScreen.deleteKey)).tap();
    final dialog = find.byKey(const ValueKey(SlotIds.diaryViewDeleteConfirm));
    await $(dialog).waitUntilVisible();
    await $(
      find.descendant(
        of: dialog,
        matching: find.text(l10n.diaryViewDeleteConfirmDelete),
      ),
    ).tap();

    // 태그 모아보기로 돌아오고, 지운 날이 빠집니다.
    await _waitUntil($, () => _rowOf(day).evaluate().isEmpty);
    expect(find.byKey(const ValueKey(ScreenIds.tagDiary)), findsOneWidget);
  });
}
