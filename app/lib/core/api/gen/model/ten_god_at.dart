//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ten_god_at.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TenGodAt {
  /// Returns a new [TenGodAt] instance.
  TenGodAt({required this.position, required this.tenGod});

  @JsonKey(name: r'position', required: true, includeIfNull: false)
  final Position position;

  @JsonKey(name: r'tenGod', required: true, includeIfNull: false)
  final TenGod tenGod;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenGodAt && other.position == position && other.tenGod == tenGod;

  @override
  int get hashCode => position.hashCode + tenGod.hashCode;

  factory TenGodAt.fromJson(Map<String, dynamic> json) =>
      _$TenGodAtFromJson(json);

  Map<String, dynamic> toJson() => _$TenGodAtToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
