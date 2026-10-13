//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'day_tags.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DayTags {
  /// Returns a new [DayTags] instance.
  DayTags({required this.featured, required this.all});

  /// 화면에 보일 대표 태그 0~2개
  @JsonKey(name: r'featured', required: true, includeIfNull: false)
  final List<Tag> featured;

  /// 전체 태그 키
  @JsonKey(name: r'all', required: true, includeIfNull: false)
  final List<String> all;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayTags && other.featured == featured && other.all == all;

  @override
  int get hashCode => featured.hashCode + all.hashCode;

  factory DayTags.fromJson(Map<String, dynamic> json) =>
      _$DayTagsFromJson(json);

  Map<String, dynamic> toJson() => _$DayTagsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
