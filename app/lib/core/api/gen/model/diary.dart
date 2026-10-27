//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/day_tags.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'diary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Diary {
  /// Returns a new [Diary] instance.
  Diary({
    required this.id,

    required this.date,

    required this.body,

    this.guideQuestion,

    required this.tags,

    required this.rulesetVersion,

    this.dayKind,

    required this.createdAt,

    required this.updatedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'guideQuestion', required: false, includeIfNull: false)
  final RenderedText? guideQuestion;

  @JsonKey(name: r'tags', required: true, includeIfNull: false)
  final DayTags tags;

  @JsonKey(name: r'rulesetVersion', required: true, includeIfNull: false)
  final String rulesetVersion;

  @JsonKey(name: r'dayKind', required: false, includeIfNull: false)
  final DayKind? dayKind;

  @JsonKey(name: r'createdAt', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'updatedAt', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Diary &&
          other.id == id &&
          other.date == date &&
          other.body == body &&
          other.guideQuestion == guideQuestion &&
          other.tags == tags &&
          other.rulesetVersion == rulesetVersion &&
          other.dayKind == dayKind &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      id.hashCode +
      date.hashCode +
      body.hashCode +
      guideQuestion.hashCode +
      tags.hashCode +
      rulesetVersion.hashCode +
      dayKind.hashCode +
      createdAt.hashCode +
      updatedAt.hashCode;

  factory Diary.fromJson(Map<String, dynamic> json) => _$DiaryFromJson(json);

  Map<String, dynamic> toJson() => _$DiaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
