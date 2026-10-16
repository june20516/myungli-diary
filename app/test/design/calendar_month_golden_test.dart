import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../support/golden.dart';

final _today = CalendarDate(2026, 10, 16);
final _selected = CalendarDate(2026, 10, 21);

/// 2026년 10월 표시 조합: 길흉(좋은·조심), 초하루·절기(굵게), 일기 도장, 일정 점,
/// 오늘(16일), 선택+일기(21일), 선택만(로딩 판에서는 없음), 바깥 달.
DayCellData _cellOf(CalendarDate date, {required bool loaded}) {
  final inMonth = date.month == 10;
  final day = date.day;
  final lunarDay = inMonth ? (day + 20) % 30 + 1 : (day % 30) + 1;
  final lunarText = switch ((date.month, day)) {
    (10, 8) => '한로',
    (10, 23) => '상강',
    _ when lunarDay == 1 => '${inMonth ? 9 : 10}.1',
    _ => '$lunarDay',
  };
  return DayCellData(
    date: date,
    luck: !loaded
        ? null
        : day % 5 == 1
        ? DayLuck.good
        : day % 7 == 3
        ? DayLuck.caution
        : DayLuck.neutral,
    lunarText: lunarText,
    lunarBold: lunarText == '한로' || lunarText == '상강',
    // 일기 도장은 칸 값과 함께 오므로 로딩 중에는 없습니다(도장 자리 skeleton만).
    diaryWritten: loaded && inMonth && const {2, 6, 11, 14, 21}.contains(day),
    eventCount: inMonth && const {6, 11, 16, 21, 29}.contains(day) ? 2 : 0,
    semanticLabel: '${date.month}월 ${date.day}일',
  );
}

Widget _month({required bool loading}) => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final colors = context.tokens.colors;
    return CalendarMonthView(
      month: const CalendarMonth(2026, 10),
      title: ja ? '2026年10月' : '2026년 10월',
      weekdayLabels: ja
          ? const ['日', '月', '火', '水', '木', '金', '土']
          : const ['일', '월', '화', '수', '목', '금', '토'],
      cellOf: (date) => _cellOf(date, loaded: !loading),
      loading: loading,
      today: _today,
      selected: _selected,
      skeletonDelay: Duration.zero,
      skeletonAnimated: false,
      onSelect: (_) {},
      onMonthChange: (_) {},
      legend: [
        (swatch: colors.calendarGoodBg, label: ja ? '良い日' : '잘 풀리는 날'),
        (swatch: colors.calendarCautionBg, label: ja ? '注意する日' : '조심할 날'),
      ],
    );
  },
);

Finder _number() => find.descendant(
  of: find.byKey(DayCell.numberKey),
  matching: find.byType(Text),
);

void main() {
  goldenTest('calendar-month: 오늘·선택·도장·일정·절기·바깥 달', (tester) async {
    await goldenMatrix(
      tester,
      'calendar_month',
      () => _month(loading: false),
      fixedCells: true,
      fixedCellTarget: _number,
    );
  });

  goldenTest('calendar-month: loading(길흉·도장 자리 skeleton, 숫자는 바로)', (
    tester,
  ) async {
    await goldenMatrix(
      tester,
      'calendar_month_loading',
      () => _month(loading: true),
      fixedCells: true,
      fixedCellTarget: _number,
    );
  });
}
