import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 일기 쓰기 화면이 여는 대상. 날짜의 새 일기이거나, 이미 있는 일기 한 편입니다.
@immutable
sealed class DiaryEditTarget {
  const new();

  /// [date]에 새로 쓰는 일기.
  const factory newOn(CalendarDate date) = NewDiaryEditTarget;

  /// 이미 있는 [id] 일기를 고칩니다. 날짜는 받아 온 일기가 압니다.
  const factory existing(String id) = ExistingDiaryEditTarget;
}

/// 날짜의 새 일기 대상.
final class NewDiaryEditTarget extends DiaryEditTarget {
  /// [date]의 새 일기 대상을 만듭니다.
  const new(this.date);

  /// 일기 날짜.
  final CalendarDate date;

  @override
  bool operator ==(Object other) =>
      other is NewDiaryEditTarget && other.date == date;

  @override
  int get hashCode => Object.hash(NewDiaryEditTarget, date);
}

/// 이미 있는 일기를 고치는 대상.
final class ExistingDiaryEditTarget extends DiaryEditTarget {
  /// [id] 일기 대상을 만듭니다.
  const new(this.id);

  /// 일기 id.
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ExistingDiaryEditTarget && other.id == id;

  @override
  int get hashCode => Object.hash(ExistingDiaryEditTarget, id);
}
