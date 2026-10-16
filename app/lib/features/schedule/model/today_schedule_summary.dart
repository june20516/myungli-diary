import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';

/// 오늘 요약 한 줄이 가리키는 일정의 상태(A35).
///
/// presentation이 `event-row`의 `EventRowStatus`로 옮깁니다(application은 design을 모름).
enum TodayScheduleStatus {
  /// 지금 이후 첫 시각 일정.
  next,

  /// 남은 시각 일정이 없고 하루 종일 일정이 있음. 시각 일정은 길이가 없어 진행 중이 되지 않습니다.
  inProgress,
}

/// 오늘 일정 요약(`today.event.summary`, A35). 일정이 없거나 불러오지 못하면 요약 자체가 null입니다.
sealed class TodayScheduleSummary {
  const new();
}

/// 일정 하나를 가리키는 요약: 상태 꼬리표·시각·제목·'외 N개'.
@immutable
final class TodayScheduleHighlight extends TodayScheduleSummary {
  /// 요약 재료.
  const new({
    required this.status,
    required this.time,
    required this.title,
    required this.moreCount,
  });

  /// 상태 꼬리표.
  final TodayScheduleStatus status;

  /// 'HH:MM'(프로필 시간대 벽시계). 하루 종일이면 null입니다.
  final String? time;

  /// 일정 제목.
  final String title;

  /// 오늘 나머지 일정 수(오늘 일정 수 − 1). 0이면 '외 N개'를 그리지 않습니다.
  final int moreCount;

  @override
  bool operator ==(Object other) =>
      other is TodayScheduleHighlight &&
      other.status == status &&
      other.time == time &&
      other.title == title &&
      other.moreCount == moreCount;

  @override
  int get hashCode => Object.hash(status, time, title, moreCount);

  @override
  String toString() =>
      'TodayScheduleHighlight($status, $time, $title, +$moreCount)';
}

/// 오늘 시각 일정이 모두 지났고 하루 종일 일정이 없음: 개수 문장 재료.
@immutable
final class TodayScheduleAllPast extends TodayScheduleSummary {
  /// 오늘 일정 [count]개.
  const new({required this.count});

  /// 오늘 일정 수.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TodayScheduleAllPast && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'TodayScheduleAllPast($count)';
}

/// 오늘 일정 [schedules]를 벽시계 [now]로 요약합니다(A35). 없으면 null입니다.
///
/// [now]는 `nowMinuteProvider` 값(UTC 그릇에 담은 프로필 시간대 벽시계)이고 시·분만 읽습니다.
/// 일정 `time`도 같은 벽시계이므로 'HH:MM' 글자 비교로 충분합니다.
///
/// 1. 지금 이후 첫 시각 일정이 "다음"입니다. 지금과 같은 분의 일정은 아직 "다음"입니다
///    (분 시계가 다음 분으로 넘어가야 지난 것이 됩니다).
/// 2. 그런 일정이 없고 하루 종일 일정이 있으면 첫 하루 종일 일정이 "진행 중"입니다.
/// 3. 모두 지났으면 개수 문장 재료입니다.
TodayScheduleSummary? summarizeTodaySchedules(
  List<Schedule> schedules, {
  required DateTime now,
}) {
  if (schedules.isEmpty) {
    return null;
  }
  final moreCount = schedules.length - 1;
  final nowText = _hhmm(now);
  final upcoming =
      schedules
          .where((s) => !s.allDay && s.time != null)
          .where((s) => s.time!.compareTo(nowText) >= 0)
          .toList()
        ..sort((a, b) => a.time!.compareTo(b.time!));
  if (upcoming.isNotEmpty) {
    final next = upcoming.first;
    return TodayScheduleHighlight(
      status: TodayScheduleStatus.next,
      time: next.time,
      title: next.title,
      moreCount: moreCount,
    );
  }
  for (final schedule in schedules) {
    if (schedule.allDay) {
      return TodayScheduleHighlight(
        status: TodayScheduleStatus.inProgress,
        time: null,
        title: schedule.title,
        moreCount: moreCount,
      );
    }
  }
  return TodayScheduleAllPast(count: schedules.length);
}

String _hhmm(DateTime wallClock) =>
    '${wallClock.hour.toString().padLeft(2, '0')}:'
    '${wallClock.minute.toString().padLeft(2, '0')}';
