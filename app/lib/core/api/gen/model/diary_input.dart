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
  DiaryInput({
    required this.date,

    required this.body,

    this.guideQuestion,

    this.withoutGuideQuestion = false,
  });

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'guideQuestion', required: false, includeIfNull: false)
  final GuideChoice? guideQuestion;

  /// true면 이 편에 가이드 질문을 붙이지 않습니다(D116, 1.10.0에서 더함). `guideQuestion`과 함께 보내지 않습니다.
  @JsonKey(
    defaultValue: false,
    name: r'withoutGuideQuestion',
    required: false,
    includeIfNull: false,
  )
  final bool? withoutGuideQuestion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryInput &&
          other.date == date &&
          other.body == body &&
          other.guideQuestion == guideQuestion &&
          other.withoutGuideQuestion == withoutGuideQuestion;

  @override
  int get hashCode =>
      date.hashCode +
      body.hashCode +
      guideQuestion.hashCode +
      withoutGuideQuestion.hashCode;

  factory DiaryInput.fromJson(Map<String, dynamic> json) =>
      _$DiaryInputFromJson(json);

  Map<String, dynamic> toJson() => _$DiaryInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
