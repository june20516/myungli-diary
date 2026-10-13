//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/direction.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'direction_card.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DirectionCard {
  /// Returns a new [DirectionCard] instance.
  DirectionCard({required this.direction, required this.text});

  @JsonKey(name: r'direction', required: true, includeIfNull: false)
  final Direction direction;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final SlotText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectionCard &&
          other.direction == direction &&
          other.text == text;

  @override
  int get hashCode => direction.hashCode + text.hashCode;

  factory DirectionCard.fromJson(Map<String, dynamic> json) =>
      _$DirectionCardFromJson(json);

  Map<String, dynamic> toJson() => _$DirectionCardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
