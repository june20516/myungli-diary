//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/strength_level.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'strength.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Strength {
  /// Returns a new [Strength] instance.
  Strength({required this.score, required this.level});

  @JsonKey(name: r'score', required: true, includeIfNull: false)
  final num score;

  @JsonKey(name: r'level', required: true, includeIfNull: false)
  final StrengthLevel level;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Strength && other.score == score && other.level == level;

  @override
  int get hashCode => score.hashCode + level.hashCode;

  factory Strength.fromJson(Map<String, dynamic> json) =>
      _$StrengthFromJson(json);

  Map<String, dynamic> toJson() => _$StrengthToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
