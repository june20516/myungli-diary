//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'diary_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiarySummary {
  /// Returns a new [DiarySummary] instance.
  DiarySummary({
    required this.date,

    required this.excerpt,

    required this.featuredTags,
  });

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  /// 본문 앞 100자
  @JsonKey(name: r'excerpt', required: true, includeIfNull: false)
  final String excerpt;

  @JsonKey(name: r'featuredTags', required: true, includeIfNull: false)
  final List<Tag> featuredTags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiarySummary &&
          other.date == date &&
          other.excerpt == excerpt &&
          other.featuredTags == featuredTags;

  @override
  int get hashCode => date.hashCode + excerpt.hashCode + featuredTags.hashCode;

  factory DiarySummary.fromJson(Map<String, dynamic> json) =>
      _$DiarySummaryFromJson(json);

  Map<String, dynamic> toJson() => _$DiarySummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
