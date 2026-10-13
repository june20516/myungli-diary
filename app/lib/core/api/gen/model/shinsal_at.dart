//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'shinsal_at.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ShinsalAt {
  /// Returns a new [ShinsalAt] instance.
  ShinsalAt({required this.kind, required this.position});

  @JsonKey(name: r'kind', required: true, includeIfNull: false)
  final ShinsalKind kind;

  @JsonKey(name: r'position', required: true, includeIfNull: false)
  final Position position;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShinsalAt && other.kind == kind && other.position == position;

  @override
  int get hashCode => kind.hashCode + position.hashCode;

  factory ShinsalAt.fromJson(Map<String, dynamic> json) =>
      _$ShinsalAtFromJson(json);

  Map<String, dynamic> toJson() => _$ShinsalAtToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
