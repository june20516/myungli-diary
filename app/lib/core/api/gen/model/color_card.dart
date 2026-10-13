//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/element_role.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'color_card.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ColorCard {
  /// Returns a new [ColorCard] instance.
  ColorCard({required this.element, required this.role, required this.text});

  @JsonKey(name: r'element', required: true, includeIfNull: false)
  final FiveElement element;

  @JsonKey(name: r'role', required: true, includeIfNull: false)
  final ElementRole role;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final SlotText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorCard &&
          other.element == element &&
          other.role == role &&
          other.text == text;

  @override
  int get hashCode => element.hashCode + role.hashCode + text.hashCode;

  factory ColorCard.fromJson(Map<String, dynamic> json) =>
      _$ColorCardFromJson(json);

  Map<String, dynamic> toJson() => _$ColorCardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
