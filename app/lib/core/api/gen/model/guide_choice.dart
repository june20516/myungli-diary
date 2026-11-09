//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'guide_choice.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GuideChoice {
  /// Returns a new [GuideChoice] instance.
  GuideChoice({required this.messageKey, required this.variant});

  @JsonKey(name: r'messageKey', required: true, includeIfNull: false)
  final String messageKey;

  @JsonKey(name: r'variant', required: true, includeIfNull: false)
  final String variant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuideChoice &&
          other.messageKey == messageKey &&
          other.variant == variant;

  @override
  int get hashCode => messageKey.hashCode + variant.hashCode;

  factory GuideChoice.fromJson(Map<String, dynamic> json) =>
      _$GuideChoiceFromJson(json);

  Map<String, dynamic> toJson() => _$GuideChoiceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
