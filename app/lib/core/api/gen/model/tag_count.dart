//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tag_count.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TagCount {
  /// Returns a new [TagCount] instance.
  TagCount({required this.tag, required this.days});

  @JsonKey(name: r'tag', required: true, includeIfNull: false)
  final Tag tag;

  /// 그 대표 태그가 붙은, 살아 있는 일기가 있는 날짜 수
  // minimum: 1
  @JsonKey(name: r'days', required: true, includeIfNull: false)
  final int days;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagCount && other.tag == tag && other.days == days;

  @override
  int get hashCode => tag.hashCode + days.hashCode;

  factory TagCount.fromJson(Map<String, dynamic> json) =>
      _$TagCountFromJson(json);

  Map<String, dynamic> toJson() => _$TagCountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
