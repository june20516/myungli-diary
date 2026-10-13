//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reaction_input.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReactionInput {
  /// Returns a new [ReactionInput] instance.
  ReactionInput({required this.reaction});

  @JsonKey(name: r'reaction', required: true, includeIfNull: false)
  final ReactionInputReactionEnum reaction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReactionInput && other.reaction == reaction;

  @override
  int get hashCode => reaction.hashCode;

  factory ReactionInput.fromJson(Map<String, dynamic> json) =>
      _$ReactionInputFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ReactionInputReactionEnum {
  @JsonValue(r'like')
  like(r'like');

  const ReactionInputReactionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
