//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'number_card.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NumberCard {
  /// Returns a new [NumberCard] instance.
  NumberCard({required this.number, required this.text});

  @JsonKey(name: r'number', required: true, includeIfNull: false)
  final int number;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final SlotText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NumberCard && other.number == number && other.text == text;

  @override
  int get hashCode => number.hashCode + text.hashCode;

  factory NumberCard.fromJson(Map<String, dynamic> json) =>
      _$NumberCardFromJson(json);

  Map<String, dynamic> toJson() => _$NumberCardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
