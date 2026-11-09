//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/guide_choice.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'diary_input.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiaryInput {
  /// Returns a new [DiaryInput] instance.
  DiaryInput({required this.date, required this.body, this.guideQuestion});

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'guideQuestion', required: false, includeIfNull: false)
  final GuideChoice? guideQuestion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryInput &&
          other.date == date &&
          other.body == body &&
          other.guideQuestion == guideQuestion;

  @override
  int get hashCode => date.hashCode + body.hashCode + guideQuestion.hashCode;

  factory DiaryInput.fromJson(Map<String, dynamic> json) =>
      _$DiaryInputFromJson(json);

  Map<String, dynamic> toJson() => _$DiaryInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
