import 'package:flutter/material.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

/// 예시 칸 값: 길흉·초하루·절기·일기 도장·일정 점을 고루 섞습니다.
DayCellData _sampleCell(CalendarDate date, {bool loaded = true}) {
  final day = date.day;
  final lunarText = switch (day) {
    8 => '한로',
    10 => '9.1',
    _ => '${(day + 20) % 30 + 1}',
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
    lunarBold: lunarText == '한로',
    diaryWritten: const {2, 6, 11, 14, 21}.contains(day),
    eventCount: const {6, 11, 16, 21, 29}.contains(day) ? 2 : 0,
    semanticLabel: '${date.month}월 ${date.day}일',
  );
}

/// 달 넘김·선택이 실제로 움직이는 달 격자.
class _MonthDemo extends StatefulWidget {
  const new({
    this.loading = false,
    this.initial = const CalendarMonth(2026, 10),
  });

  final bool loading;
  final CalendarMonth initial;

  @override
  State<_MonthDemo> createState() => _MonthDemoState();
}

class _MonthDemoState extends State<_MonthDemo> {
  late CalendarMonth _month = widget.initial;
  CalendarDate? _selected = CalendarDate(2026, 10, 21);

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return CalendarMonthView(
      month: _month,
      title: '${_month.year}년 ${_month.month}월',
      weekdayLabels: const ['일', '월', '화', '수', '목', '금', '토'],
      cellOf: (date) => _sampleCell(date, loaded: !widget.loading),
      loading: widget.loading,
      today: CalendarDate(2026, 10, 16),
      selected: _selected,
      onSelect: (date) => setState(() => _selected = date),
      onMonthChange: (month) => setState(() => _month = month),
      legend: [
        (swatch: colors.calendarGoodBg, label: '잘 풀리는 날'),
        (swatch: colors.calendarCautionBg, label: '조심할 날'),
      ],
    );
  }
}

/// 날짜 칸 상태 모음: 평소·오늘·선택·선택+일기·일정·바깥 달·누를 수 없음.
class _CellStates extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final date = CalendarDate(2026, 10, 11);
    final base = DayCellData(
      date: date,
      luck: DayLuck.good,
      lunarText: '1',
      semanticLabel: '10월 11일',
    );
    final withDiary = DayCellData(
      date: date,
      luck: DayLuck.good,
      lunarText: '1',
      diaryWritten: true,
      eventCount: 1,
      semanticLabel: '10월 11일, 일기 있음, 일정 1개',
    );
    final cells = <(String, DayCell)>[
      (
        '평소',
        DayCell(
          data: base,
          isToday: false,
          isSelected: false,
          outsideMonth: false,
          onTap: () {},
        ),
      ),
      (
        '오늘',
        DayCell(
          data: base,
          isToday: true,
          isSelected: false,
          outsideMonth: false,
          onTap: () {},
        ),
      ),
      (
        '선택',
        DayCell(
          data: base,
          isToday: false,
          isSelected: true,
          outsideMonth: false,
          onTap: () {},
        ),
      ),
      (
        '선택+일기',
        DayCell(
          data: withDiary,
          isToday: false,
          isSelected: true,
          outsideMonth: false,
          onTap: () {},
        ),
      ),
      (
        '바깥 달',
        DayCell(
          data: base,
          isToday: false,
          isSelected: false,
          outsideMonth: true,
          onTap: () {},
        ),
      ),
      (
        '누를 수 없음',
        DayCell(
          data: base,
          isToday: false,
          isSelected: false,
          outsideMonth: false,
          disabled: true,
          onTap: () {},
        ),
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (label, cell) in cells)
          SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 46, child: cell),
                Text(label, style: context.tokens.typography.captionSm),
              ],
            ),
          ),
      ],
    );
  }
}

/// 달력 폴더에 넣을 `calendar-month`·`day-cell` 컴포넌트.
final List<WidgetbookComponent> calendarMonthComponents = [
  WidgetbookComponent(
    name: 'calendar-month',
    useCases: [
      WidgetbookUseCase(
        name: '기본(밀기·이전·다음)',
        builder: (context) =>
            const Stage(child: SizedBox(width: 340, child: _MonthDemo())),
      ),
      WidgetbookUseCase(
        name: 'loading',
        builder: (context) => const Stage(
          child: SizedBox(width: 340, child: _MonthDemo(loading: true)),
        ),
      ),
      WidgetbookUseCase(
        name: '범위 끝(1900-02)',
        builder: (context) => const Stage(
          child: SizedBox(
            width: 340,
            child: _MonthDemo(initial: CalendarMonth.supportedFirst),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'day-cell',
    useCases: [
      WidgetbookUseCase(
        name: '상태',
        builder: (context) => const Stage(child: _CellStates()),
      ),
    ],
  ),
];
