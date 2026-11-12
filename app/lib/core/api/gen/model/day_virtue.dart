//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/day_virtue_kind.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'day_virtue.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DayVirtue {
  /// Returns a new [DayVirtue] instance.
  DayVirtue({required this.kind, required this.text});

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DayVirtueKind.unknownDefaultOpenApi,
  )
  final DayVirtueKind kind;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final SlotText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayVirtue && other.kind == kind && other.text == text;

  @override
  int get hashCode => kind.hashCode + text.hashCode;

  factory DayVirtue.fromJson(Map<String, dynamic> json) =>
      _$DayVirtueFromJson(json);

  Map<String, dynamic> toJson() => _$DayVirtueToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
