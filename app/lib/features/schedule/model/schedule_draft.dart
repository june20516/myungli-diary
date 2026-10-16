import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_input.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_patch.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 일정 편집 화면(`event-edit`)이 들고 있는 초안.
///
/// 시각은 사용자가 휠을 건드렸는지([timeTouched])를 함께 들고 있습니다. 불러온 시각이 5분
/// 배수가 아니면 휠은 아래로 맞춘 값을 보이지만, 건드리지 않았으면 고치기 요청에 `time`을
/// 넣지 않아 원래 값이 남습니다(A36).
@immutable
final class ScheduleDraft {
  /// 새 초안. [time]은 'HH:MM'이고 하루 종일([allDay])이면 쓰지 않습니다.
  const new({
    required this.date,
    required this.allDay,
    required this.title,
    this.time,
    this.memo = '',
    this.timeTouched = false,
  });

  /// [schedule]을 그대로 옮긴 초안(시각은 건드리지 않은 상태).
  ///
  /// 휠에 보이는 5분 아래 맞춤은 presentation 몫이라, 여기서는 원래 시각을 그대로 둡니다.
  factory of(Schedule schedule) => ScheduleDraft(
    date: CalendarDate.parse(schedule.date),
    allDay: schedule.allDay,
    title: schedule.title,
    time: schedule.time,
    memo: schedule.memo ?? '',
  );

  /// 날짜(양력).
  final CalendarDate date;

  /// 하루 종일 일정인지.
  final bool allDay;

  /// 'HH:MM'(프로필 시간대 벽시계, A35). 하루 종일이면 무시합니다.
  final String? time;

  /// 제목.
  final String title;

  /// 메모. 빈 문자열이면 메모 없음입니다.
  final String memo;

  /// 사용자가 시각을 고쳤는지([withTime]으로만 true가 됩니다).
  final bool timeTouched;

  /// 시각 밖의 값을 바꾼 초안. 시각은 [withTime]으로 바꿉니다.
  ScheduleDraft copyWith({
    CalendarDate? date,
    bool? allDay,
    String? title,
    String? memo,
  }) => ScheduleDraft(
    date: date ?? this.date,
    allDay: allDay ?? this.allDay,
    title: title ?? this.title,
    time: time,
    memo: memo ?? this.memo,
    timeTouched: timeTouched,
  );

  /// 사용자가 시각을 [value]로 고친 초안.
  ScheduleDraft withTime(String value) => ScheduleDraft(
    date: date,
    allDay: allDay,
    title: title,
    time: value,
    memo: memo,
    timeTouched: true,
  );

  /// 만들기 본문. 하루 종일이면 `time`을, 빈 메모면 `memo`를 싣지 않습니다.
  ScheduleInput toInput() => ScheduleInput(
    date: date.toIso(),
    allDay: allDay,
    time: allDay ? null : time,
    title: title,
    memo: memo.isEmpty ? null : memo,
  );

  /// [original]에서 바뀐 필드만 담은 merge-patch. 바뀐 것이 없으면 null입니다.
  ///
  /// * `time`은 시각 일정이고, 하루 종일에서 시각 일정으로 바꿨거나 사용자가 시각을 고쳐
  ///   원래와 달라졌을 때만 보냅니다(A36). 하루 종일로 바꾸면 server가 `time`을 지웁니다.
  /// * 메모를 지우면 빈 문자열을 보냅니다(계약: 빈 `memo`로 지움).
  SchedulePatch? patchFrom(Schedule original) {
    final isoDate = date.toIso();
    final sendTime =
        !allDay && (original.allDay || (timeTouched && time != original.time));
    final patch = SchedulePatch(
      date: isoDate == original.date ? null : isoDate,
      allDay: allDay == original.allDay ? null : allDay,
      time: sendTime ? time : null,
      title: title == original.title ? null : title,
      memo: memo == (original.memo ?? '') ? null : memo,
    );
    return patch.toJson().isEmpty ? null : patch;
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduleDraft &&
      other.date == date &&
      other.allDay == allDay &&
      other.time == time &&
      other.title == title &&
      other.memo == memo &&
      other.timeTouched == timeTouched;

  @override
  int get hashCode => Object.hash(date, allDay, time, title, memo, timeTouched);
}
