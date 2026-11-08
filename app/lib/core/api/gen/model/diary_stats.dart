//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/day_kind_count.dart';
import 'package:myungli_diary/core/api/gen/model/tag_count.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'diary_stats.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiaryStats {
  /// Returns a new [DiaryStats] instance.
  DiaryStats({
    required this.entryCount,

    required this.dayKinds,

    required this.topTags,
  });

  /// 살아 있는 일기 편수
  // minimum: 0
  @JsonKey(name: r'entryCount', required: true, includeIfNull: false)
  final int entryCount;

  @JsonKey(name: r'dayKinds', required: true, includeIfNull: false)
  final List<DayKindCount> dayKinds;

  @JsonKey(name: r'topTags', required: true, includeIfNull: false)
  final List<TagCount> topTags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryStats &&
          other.entryCount == entryCount &&
          other.dayKinds == dayKinds &&
          other.topTags == topTags;

  @override
  int get hashCode =>
      entryCount.hashCode + dayKinds.hashCode + topTags.hashCode;

  factory DiaryStats.fromJson(Map<String, dynamic> json) =>
      _$DiaryStatsFromJson(json);

  Map<String, dynamic> toJson() => _$DiaryStatsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
