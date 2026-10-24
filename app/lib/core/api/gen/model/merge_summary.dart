//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/merge_added_days.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergeSummary {
  /// Returns a new [MergeSummary] instance.
  MergeSummary({
    required this.diaries,

    required this.schedules,

    required this.dateRecords,

    required this.reactions,

    required this.overlapDays,

    required this.addedDays,

    required this.current,

    required this.other,
  });

  /// 옮길 살아 있는 일기 수. 지운 일기도 함께 옮기지만 화면에서 되살릴 수 없어 세지 않습니다.
  // minimum: 0
  @JsonKey(name: r'diaries', required: true, includeIfNull: false)
  final int diaries;

  /// 옮길 살아 있는 일정 수. 지운 일정도 함께 옮기지만 세지 않습니다.
  // minimum: 0
  @JsonKey(name: r'schedules', required: true, includeIfNull: false)
  final int schedules;

  /// 옮길 날짜 기록 수. A와 날짜가 겹치지 않는 B의 날짜 기록만 셉니다(겹친 날은 `overlapDays`로만 셈).
  // minimum: 0
  @JsonKey(name: r'dateRecords', required: true, includeIfNull: false)
  final int dateRecords;

  /// B의 살아 있는 문장 반응 전체 수. 같은 날·같은 자리·같은 출생 정보의 문장 선택이 겹치면 고른 프로필에 따라 일부는 유저 계정과 끊긴 문장별 집계로만 남을 수 있습니다.
  // minimum: 0
  @JsonKey(name: r'reactions', required: true, includeIfNull: false)
  final int reactions;

  /// 두 유저 계정 모두 날짜 기록이 있는 날 수. 0이면 app은 겹치는 날 안내를 보이지 않습니다.
  // minimum: 0
  @JsonKey(name: r'overlapDays', required: true, includeIfNull: false)
  final int overlapDays;

  @JsonKey(name: r'addedDays', required: true, includeIfNull: false)
  final MergeAddedDays addedDays;

  @JsonKey(name: r'current', required: true, includeIfNull: false)
  final MergeProfileSummary current;

  @JsonKey(name: r'other', required: true, includeIfNull: false)
  final MergeProfileSummary other;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeSummary &&
          other.diaries == diaries &&
          other.schedules == schedules &&
          other.dateRecords == dateRecords &&
          other.reactions == reactions &&
          other.overlapDays == overlapDays &&
          other.addedDays == addedDays &&
          other.current == current &&
          other.other == other;

  @override
  int get hashCode =>
      diaries.hashCode +
      schedules.hashCode +
      dateRecords.hashCode +
      reactions.hashCode +
      overlapDays.hashCode +
      addedDays.hashCode +
      current.hashCode +
      other.hashCode;

  factory MergeSummary.fromJson(Map<String, dynamic> json) =>
      _$MergeSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$MergeSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
