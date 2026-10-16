import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    show Finder, expect, find, findsNothing, findsOneWidget, isFalse, isTrue;
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/features/schedule/presentation/event_edit_screen.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

/// 시나리오 member의 오늘입니다(일정 셋: 하루 종일·09:07·19:00).
final _today = CalendarDate(2026, 10, 13);

/// 일정을 넣었다가 지울 다음 달의 날입니다. 10월 격자(~11-07) 밖이라 11월 격자에만 있습니다.
final _target = CalendarDate(2026, 11, 18);

/// 새 일정 제목입니다.
const _title = '등산';

final Finder _daySheet = find.byKey(const ValueKey(ScreenIds.daySheet));

/// 그날 시트 안에서 [finder]를 찾습니다.
Finder _inDaySheet(Finder finder) =>
    find.descendant(of: _daySheet, matching: finder);

/// 그날 시트에 보이는 일정 제목(위에서 아래 순서).
List<String> _sheetTitles(PatrolIntegrationTester $) => [
  for (final row in $.tester.widgetList<EventRow>(
    _inDaySheet(find.byType(EventRow)),
  ))
    row.title,
];

/// 달 격자에서 [date] 칸의 [DayCell]입니다.
DayCell _cell(PatrolIntegrationTester $, CalendarDate date) =>
    $.tester.widget<DayCell>(
      find.descendant(
        of: find.byKey(CalendarMonthView.cellKey(date)),
        matching: find.byType(DayCell),
      ),
    );

/// [date] 칸에 일정 점이 있는지 봅니다.
bool _hasEventDot(CalendarDate date) => find
    .descendant(
      of: find.byKey(CalendarMonthView.cellKey(date)),
      matching: find.byKey(DayCell.eventDotKey),
    )
    .evaluate()
    .isNotEmpty;

/// [done]이 참이 될 때까지 프레임을 돌립니다(대역 서버 응답·시트 움직임을 기다림).
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
  patrolTest('member: 오늘 일정 줄 → 그날 시트, 달력 다음 달 날짜에 일정을 넣고 점을 본 뒤 지웁니다', (
    $,
  ) async {
    covers(
      const Covers(
        exits: [
          'today>day-sheet',
          'calendar>day-sheet',
          'day-sheet>event-edit',
        ],
        states: ['day-sheet:empty'],
        decisions: ['D47'],
      ),
    );
    // 일정 추가 버튼은 Semantics identifier로만 찾을 수 있습니다.
    final semantics = $.tester.ensureSemantics();
    try {
      await launchApp(
        $,
        flow: 'calendar',
        scenario: 'member',
        deviceLocale: const Locale('ko', 'KR'),
      );
      await waitForScreen($, ScreenIds.today);

      // 오늘 일정 한 줄 → 오늘 그날 시트(일정 셋).
      final summary = find.descendant(
        of: find.byKey(const ValueKey(SlotIds.todayEventSummary)),
        matching: find.byType(EventRow),
      );
      await $(summary).scrollTo();
      await $(summary).tap();
      await expectScreen($, ScreenIds.daySheet);
      await _waitUntil($, () => _sheetTitles($).length == 3);
      expect(_sheetTitles($), ['엄마 생신', '팀 주간 회의', '요가 수업']);
      await closeSheets($);
      expect(_daySheet, findsNothing);

      // 달력 탭: 오늘이 든 달, 오늘 칸에 일정 점.
      await $(find.byKey(const ValueKey('tab-bar.tab.1'))).tap();
      await expectScreen($, ScreenIds.calendar);
      await _waitUntil($, () => _hasEventDot(_today));
      expect(_cell($, _today).isToday, isTrue);

      // 다음 달 → 고른 날의 그날 시트(일정 없음).
      await $(find.byKey(CalendarMonthView.nextKey)).tap();
      await _waitUntil(
        $,
        () =>
            $.tester
                .widget<CalendarMonthView>(find.byType(CalendarMonthView))
                .month ==
            const CalendarMonth(2026, 11),
      );
      await $.pumpAndTrySettle();
      expect(_hasEventDot(_target), isFalse);
      await $(find.byKey(CalendarMonthView.cellKey(_target))).tap();
      await waitForScreen($, ScreenIds.daySheet);
      final empty = find.bySemanticsIdentifier(SlotIds.daySheetEventEmpty);
      await _waitUntil($, () => empty.evaluate().isNotEmpty);

      // 일정 추가 → 새 일정 화면에서 제목을 적고 저장하면 시트로 돌아옵니다.
      await $(_inDaySheet(find.bySemanticsIdentifier(SlotIds.daySheetEventAdd)))
          .tap();
      await expectScreen($, ScreenIds.eventEdit);
      await $(
        find.descendant(
          of: find.byKey(const ValueKey(SlotIds.eventEditTitleHint)),
          matching: find.byType(EditableText),
        ),
      ).enterText(_title);
      await $(find.byKey(EventEditScreen.saveKey)).scrollTo();
      await $(find.byKey(EventEditScreen.saveKey)).tap();
      await _waitUntil(
        $,
        () =>
            find.byKey(const ValueKey(ScreenIds.eventEdit)).evaluate().isEmpty,
      );

      // 시트에 새 일정 한 줄, 달 격자의 그 칸에 점.
      await _waitUntil($, () => _sheetTitles($).contains(_title));
      expect(_sheetTitles($), [_title]);
      await _waitUntil($, () => _hasEventDot(_target));
      expect(_cell($, _target).data.eventCount, 1);

      // 일정을 눌러 고치기 화면 → 지우기 → 확인 창에서 지우기.
      await $(_inDaySheet(find.widgetWithText(EventRow, _title))).tap();
      await waitForScreen($, ScreenIds.eventEdit);
      await $(find.byKey(EventEditScreen.deleteKey)).scrollTo();
      await $(find.byKey(EventEditScreen.deleteKey)).tap();
      final dialog = find.byKey(const ValueKey(SlotIds.eventEditDeleteConfirm));
      await $(dialog).waitUntilVisible();
      final l10n = AppLocalizations.of($.tester.element(dialog));
      await $(
        find.descendant(
          of: dialog,
          matching: find.text(l10n.eventEditDeleteConfirmDelete),
        ),
      ).tap();
      await _waitUntil(
        $,
        () =>
            find.byKey(const ValueKey(ScreenIds.eventEdit)).evaluate().isEmpty,
      );

      // 시트는 다시 비고, 칸의 점이 사라집니다.
      await _waitUntil($, () => empty.evaluate().isNotEmpty);
      await _waitUntil($, () => !_hasEventDot(_target));
      expect(_cell($, _target).data.eventCount, 0);
      await closeSheets($);
      expect(find.byKey(const ValueKey(ScreenIds.calendar)), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
