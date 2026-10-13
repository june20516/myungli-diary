//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'twelve_stage_at.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TwelveStageAt {
  /// Returns a new [TwelveStageAt] instance.
  TwelveStageAt({required this.position, required this.stage});

  @JsonKey(name: r'position', required: true, includeIfNull: false)
  final Position position;

  @JsonKey(name: r'stage', required: true, includeIfNull: false)
  final TwelveStage stage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TwelveStageAt &&
          other.position == position &&
          other.stage == stage;

  @override
  int get hashCode => position.hashCode + stage.hashCode;

  factory TwelveStageAt.fromJson(Map<String, dynamic> json) =>
      _$TwelveStageAtFromJson(json);

  Map<String, dynamic> toJson() => _$TwelveStageAtToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
