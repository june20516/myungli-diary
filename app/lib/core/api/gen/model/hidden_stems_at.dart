//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/hidden_stem.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hidden_stems_at.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HiddenStemsAt {
  /// Returns a new [HiddenStemsAt] instance.
  HiddenStemsAt({required this.position, required this.stems});

  @JsonKey(name: r'position', required: true, includeIfNull: false)
  final Position position;

  @JsonKey(name: r'stems', required: true, includeIfNull: false)
  final List<HiddenStem> stems;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiddenStemsAt &&
          other.position == position &&
          other.stems == stems;

  @override
  int get hashCode => position.hashCode + stems.hashCode;

  factory HiddenStemsAt.fromJson(Map<String, dynamic> json) =>
      _$HiddenStemsAtFromJson(json);

  Map<String, dynamic> toJson() => _$HiddenStemsAtToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
