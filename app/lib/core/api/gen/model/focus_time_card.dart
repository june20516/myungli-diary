//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'focus_time_card.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FocusTimeCard {
  /// Returns a new [FocusTimeCard] instance.
  FocusTimeCard({
    required this.picks,

    required this.fallback,

    required this.text,
  });

  @JsonKey(name: r'picks', required: true, includeIfNull: false)
  final List<FocusSlot> picks;

  @JsonKey(name: r'fallback', required: true, includeIfNull: false)
  final bool fallback;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final SlotText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusTimeCard &&
          other.picks == picks &&
          other.fallback == fallback &&
          other.text == text;

  @override
  int get hashCode => picks.hashCode + fallback.hashCode + text.hashCode;

  factory FocusTimeCard.fromJson(Map<String, dynamic> json) =>
      _$FocusTimeCardFromJson(json);

  Map<String, dynamic> toJson() => _$FocusTimeCardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
