import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 일정을 받는 날짜 범위(`from`·`to` 둘 다 포함). `listSchedules` 한도는 62일입니다.
///
/// 달력은 보이는 6주 격자(42일), 오늘 화면과 그날 시트는 하루(`from == to`)를 씁니다.
typedef ScheduleRange = ({CalendarDate from, CalendarDate to});

/// [range]가 [date]를 품는지.
bool rangeContains(ScheduleRange range, CalendarDate date) =>
    date.compareTo(range.from) >= 0 && date.compareTo(range.to) <= 0;
