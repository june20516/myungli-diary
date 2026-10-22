//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'diary_body_input.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiaryBodyInput {
  /// Returns a new [DiaryBodyInput] instance.
  DiaryBodyInput({required this.body});

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DiaryBodyInput && other.body == body;

  @override
  int get hashCode => body.hashCode;

  factory DiaryBodyInput.fromJson(Map<String, dynamic> json) =>
      _$DiaryBodyInputFromJson(json);

  Map<String, dynamic> toJson() => _$DiaryBodyInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
