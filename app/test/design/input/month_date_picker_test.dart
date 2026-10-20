import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/input/month_date_picker.dart';

import 'input_harness.dart';

final _today = CalendarDate(2026, 10, 13);

Widget _picker({
  CalendarMonth month = const CalendarMonth(2026, 10),
  CalendarDate? selected,
  Set<CalendarDate> marked = const {},
  ValueChanged<CalendarDate>? onSelect,
  ValueChanged<CalendarMonth>? onMonthChange,
  VoidCallback? onConfirm,
}) => inputApp(
  SingleChildScrollView(
    child: SizedBox(
      width: 360,
      child: MonthDatePicker(
        month: month,
        selected: selected ?? _today,
        today: _today,
        markedDates: marked,
        onSelect: onSelect ?? (_) {},
        onMonthChange: onMonthChange ?? (_) {},
        confirmLabel: '10월 13일 일기',
        onConfirm: onConfirm ?? () {},
      ),
    ),
  ),
);

void main() {
  group('date-picker calendar', () {
    testWidgets('calendar-month와 같은 칸이고 길흉 채우기만 없습니다, 일기 쓴 날은 도장', (
      tester,
    ) async {
      await tester.pumpWidget(_picker(marked: {CalendarDate(2026, 10, 12)}));
      final month = tester.widget<CalendarMonthView>(
        find.byType(CalendarMonthView),
      );
      expect(month.title, '2026년 10월');
      expect(month.weekdayLabels.first, '일');
      for (var day = 1; day <= 31; day++) {
        final cell = month.cellOf(CalendarDate(2026, 10, day));
        expect(cell.luck, isNull);
        expect(cell.lunarText, isNull);
        expect(cell.diaryWritten, day == 12);
      }
      expect(month.today, _today);
      expect(month.selected, _today);
    });

    testWidgets('미래 날짜는 누를 수 없고 지난 날·오늘은 고릅니다', (tester) async {
      final picked = <CalendarDate>[];
      await tester.pumpWidget(_picker(onSelect: picked.add));
      final month = tester.widget<CalendarMonthView>(
        find.byType(CalendarMonthView),
      );
      expect(month.isDateEnabled!(CalendarDate(2026, 10, 14)), isFalse);
      expect(month.isDateEnabled!(_today), isTrue);
      await tester.tap(
        find.byKey(CalendarMonthView.cellKey(CalendarDate(2026, 10, 20))),
      );
      await tester.tap(
        find.byKey(CalendarMonthView.cellKey(CalendarDate(2026, 10, 2))),
      );
      await tester.pumpAndSettle();
      expect(picked, [CalendarDate(2026, 10, 2)]);
    });

    testWidgets('오늘이 든 달 다음으로는 넘어가지 않고 이전 달로는 넘어갑니다', (tester) async {
      final months = <CalendarMonth>[];
      await tester.pumpWidget(_picker(onMonthChange: months.add));
      await tester.tap(find.byKey(CalendarMonthView.nextKey));
      await tester.tap(find.byKey(CalendarMonthView.prevKey));
      await tester.pumpAndSettle();
      expect(months, [const CalendarMonth(2026, 9)]);
    });

    testWidgets('아래 버튼은 고른 날짜를 넣은 글자이고 누르면 onConfirm', (tester) async {
      var confirms = 0;
      await tester.pumpWidget(_picker(onConfirm: () => confirms++));
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.label, '10월 13일 일기');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(confirms, 1);
    });

    testWidgets('칸 스크린리더 라벨은 날짜·요일과 일기 씀·오늘입니다', (tester) async {
      await tester.pumpWidget(_picker(marked: {_today}));
      final month = tester.widget<CalendarMonthView>(
        find.byType(CalendarMonthView),
      );
      final cell = month.cellOf(_today);
      expect(cell.semanticLabel, '10월 13일 화요일, 일기 있음, 오늘');
    });
  });
}
