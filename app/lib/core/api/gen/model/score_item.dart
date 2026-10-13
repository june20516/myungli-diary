//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'score_item.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ScoreItem {
  /// Returns a new [ScoreItem] instance.
  ScoreItem({required this.id, required this.score});

  /// glossary `score_item` 범주의 키
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'score', required: true, includeIfNull: false)
  final int score;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreItem && other.id == id && other.score == score;

  @override
  int get hashCode => id.hashCode + score.hashCode;

  factory ScoreItem.fromJson(Map<String, dynamic> json) =>
      _$ScoreItemFromJson(json);

  Map<String, dynamic> toJson() => _$ScoreItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
