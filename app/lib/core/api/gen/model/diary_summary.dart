//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
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
    required this.id,

    required this.date,

    required this.createdAt,

    required this.excerpt,

    required this.featuredTags,

    this.dayKind,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'createdAt', required: true, includeIfNull: false)
  final DateTime createdAt;

  /// 본문 앞 100자
  @JsonKey(name: r'excerpt', required: true, includeIfNull: false)
  final String excerpt;

  @JsonKey(name: r'featuredTags', required: true, includeIfNull: false)
  final List<Tag> featuredTags;

  @JsonKey(name: r'dayKind', required: false, includeIfNull: false)
  final DayKind? dayKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiarySummary &&
          other.id == id &&
          other.date == date &&
          other.createdAt == createdAt &&
          other.excerpt == excerpt &&
          other.featuredTags == featuredTags &&
          other.dayKind == dayKind;

  @override
  int get hashCode =>
      id.hashCode +
      date.hashCode +
      createdAt.hashCode +
      excerpt.hashCode +
      featuredTags.hashCode +
      dayKind.hashCode;

  factory DiarySummary.fromJson(Map<String, dynamic> json) =>
      _$DiarySummaryFromJson(json);

  Map<String, dynamic> toJson() => _$DiarySummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
