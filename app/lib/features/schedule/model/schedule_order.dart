import 'package:myungli_diary/core/api/gen/model/schedule.dart';

/// 하루 일정 목록 순서: 하루 종일 먼저, 그다음 시각순('HH:MM'), 같으면 만든 순서입니다.
///
/// `day-sheet` 목록(`event-row` `list`)이 이 순서로 그립니다. [schedules]는 바꾸지 않습니다.
List<Schedule> inDayOrder(Iterable<Schedule> schedules) =>
    schedules.toList()..sort(_compare);

int _compare(Schedule a, Schedule b) {
  if (a.allDay != b.allDay) {
    return a.allDay ? -1 : 1;
  }
  final byTime = (a.time ?? '').compareTo(b.time ?? '');
  if (byTime != 0) {
    return byTime;
  }
  return a.createdAt.compareTo(b.createdAt);
}
