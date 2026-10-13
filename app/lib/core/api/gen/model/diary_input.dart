//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
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
  DiaryInput({required this.body});

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DiaryInput && other.body == body;

  @override
  int get hashCode => body.hashCode;

  factory DiaryInput.fromJson(Map<String, dynamic> json) =>
      _$DiaryInputFromJson(json);

  Map<String, dynamic> toJson() => _$DiaryInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
