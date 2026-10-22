import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 일기 초안이 붙는 대상. 날짜의 새 일기이거나, 이미 있는 일기 한 편입니다.
@immutable
sealed class DiaryDraftTarget {
  const new();

  /// [date]에 새로 쓰는 일기. 날짜마다 초안은 하나입니다.
  const factory newOn(CalendarDate date) = NewDiaryDraftTarget;

  /// [date]의 [id] 일기를 고치는 초안.
  const factory existing({required CalendarDate date, required String id}) =
      ExistingDiaryDraftTarget;

  /// 일기 날짜.
  CalendarDate get date;

  /// 초안 저장소 키의 일기 id. 새 일기는 빈 문자열입니다.
  String get diaryId;

  @override
  bool operator ==(Object other) =>
      other is DiaryDraftTarget &&
      other.runtimeType == runtimeType &&
      other.date == date &&
      other.diaryId == diaryId;

  @override
  int get hashCode => Object.hash(runtimeType, date, diaryId);
}

/// 날짜의 새 일기 초안 대상.
final class NewDiaryDraftTarget extends DiaryDraftTarget {
  /// [date]의 새 일기 대상을 만듭니다.
  const new(this.date);

  @override
  final CalendarDate date;

  @override
  String get diaryId => '';
}

/// 이미 있는 일기를 고치는 초안 대상.
final class ExistingDiaryDraftTarget extends DiaryDraftTarget {
  /// [date]의 [id] 일기 대상을 만듭니다.
  const new({required this.date, required String id}) : diaryId = id;

  @override
  final CalendarDate date;

  @override
  final String diaryId;
}
