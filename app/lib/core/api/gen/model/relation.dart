//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/relation_kind.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'relation.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Relation {
  /// Returns a new [Relation] instance.
  Relation({
    required this.kind,

    required this.natalPosition,

    required this.suppressed,

    this.suppressedBy,
  });

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RelationKind.unknownDefaultOpenApi,
  )
  final RelationKind kind;

  @JsonKey(name: r'natalPosition', required: true, includeIfNull: false)
  final Position natalPosition;

  @JsonKey(name: r'suppressed', required: true, includeIfNull: false)
  final bool suppressed;

  @JsonKey(
    name: r'suppressedBy',
    required: false,
    includeIfNull: false,
    unknownEnumValue: RelationKind.unknownDefaultOpenApi,
  )
  final RelationKind? suppressedBy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Relation &&
          other.kind == kind &&
          other.natalPosition == natalPosition &&
          other.suppressed == suppressed &&
          other.suppressedBy == suppressedBy;

  @override
  int get hashCode =>
      kind.hashCode +
      natalPosition.hashCode +
      suppressed.hashCode +
      suppressedBy.hashCode;

  factory Relation.fromJson(Map<String, dynamic> json) =>
      _$RelationFromJson(json);

  Map<String, dynamic> toJson() => _$RelationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
