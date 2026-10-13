// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'color_card.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ColorCardCWProxy {
  ColorCard element(FiveElement element);

  ColorCard role(ElementRole role);

  ColorCard text(SlotText text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ColorCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ColorCard(...).copyWith(id: 12, name: "My name")
  /// ```
  ColorCard call({FiveElement element, ElementRole role, SlotText text});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfColorCard.copyWith(...)` or call `instanceOfColorCard.copyWith.fieldName(value)` for a single field.
class _$ColorCardCWProxyImpl implements _$ColorCardCWProxy {
  const _$ColorCardCWProxyImpl(this._value);

  final ColorCard _value;

  @override
  ColorCard element(FiveElement element) => call(element: element);

  @override
  ColorCard role(ElementRole role) => call(role: role);

  @override
  ColorCard text(SlotText text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ColorCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ColorCard(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ColorCard call({
    Object? element = const $CopyWithPlaceholder(),
    Object? role = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
  }) {
    return ColorCard(
      element: element == const $CopyWithPlaceholder() || element == null
          ? _value.element
          // ignore: cast_nullable_to_non_nullable
          : element as FiveElement,
      role: role == const $CopyWithPlaceholder() || role == null
          ? _value.role
          // ignore: cast_nullable_to_non_nullable
          : role as ElementRole,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as SlotText,
    );
  }
}

extension $ColorCardCopyWith on ColorCard {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfColorCard.copyWith(...)` or `instanceOfColorCard.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ColorCardCWProxy get copyWith => _$ColorCardCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ColorCard _$ColorCardFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ColorCard', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['element', 'role', 'text']);
      final val = ColorCard(
        element: $checkedConvert(
          'element',
          (v) => $enumDecode(_$FiveElementEnumMap, v),
        ),
        role: $checkedConvert(
          'role',
          (v) => $enumDecode(_$ElementRoleEnumMap, v),
        ),
        text: $checkedConvert(
          'text',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ColorCardToJson(ColorCard instance) => <String, dynamic>{
  'element': _$FiveElementEnumMap[instance.element]!,
  'role': _$ElementRoleEnumMap[instance.role]!,
  'text': instance.text.toJson(),
};

const _$FiveElementEnumMap = {
  FiveElement.wood: 'wood',
  FiveElement.fire: 'fire',
  FiveElement.earth: 'earth',
  FiveElement.metal: 'metal',
  FiveElement.water: 'water',
};

const _$ElementRoleEnumMap = {
  ElementRole.yongsin: 'yongsin',
  ElementRole.tonggwan: 'tonggwan',
};
