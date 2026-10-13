//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/direction_card.dart';
import 'package:myungli_diary/core/api/gen/model/number_card.dart';
import 'package:myungli_diary/core/api/gen/model/color_card.dart';
import 'package:myungli_diary/core/api/gen/model/focus_time_card.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_cards.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DailyCards {
  /// Returns a new [DailyCards] instance.
  DailyCards({
    required this.color,

    required this.direction,

    required this.number,

    required this.focusTime,
  });

  @JsonKey(name: r'color', required: true, includeIfNull: false)
  final ColorCard color;

  @JsonKey(name: r'direction', required: true, includeIfNull: false)
  final DirectionCard direction;

  @JsonKey(name: r'number', required: true, includeIfNull: false)
  final NumberCard number;

  @JsonKey(name: r'focusTime', required: true, includeIfNull: false)
  final FocusTimeCard focusTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCards &&
          other.color == color &&
          other.direction == direction &&
          other.number == number &&
          other.focusTime == focusTime;

  @override
  int get hashCode =>
      color.hashCode +
      direction.hashCode +
      number.hashCode +
      focusTime.hashCode;

  factory DailyCards.fromJson(Map<String, dynamic> json) =>
      _$DailyCardsFromJson(json);

  Map<String, dynamic> toJson() => _$DailyCardsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
