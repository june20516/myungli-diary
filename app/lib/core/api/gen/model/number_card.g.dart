// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'number_card.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NumberCardCWProxy {
  NumberCard number(int number);

  NumberCard text(SlotText text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NumberCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NumberCard(...).copyWith(id: 12, name: "My name")
  /// ```
  NumberCard call({int number, SlotText text});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfNumberCard.copyWith(...)` or call `instanceOfNumberCard.copyWith.fieldName(value)` for a single field.
class _$NumberCardCWProxyImpl implements _$NumberCardCWProxy {
  const _$NumberCardCWProxyImpl(this._value);

  final NumberCard _value;

  @override
  NumberCard number(int number) => call(number: number);

  @override
  NumberCard text(SlotText text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `NumberCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// NumberCard(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  NumberCard call({
    Object? number = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
  }) {
    return NumberCard(
      number: number == const $CopyWithPlaceholder() || number == null
          ? _value.number
          // ignore: cast_nullable_to_non_nullable
          : number as int,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as SlotText,
    );
  }
}

extension $NumberCardCopyWith on NumberCard {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfNumberCard.copyWith(...)` or `instanceOfNumberCard.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NumberCardCWProxy get copyWith => _$NumberCardCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NumberCard _$NumberCardFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NumberCard', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['number', 'text']);
      final val = NumberCard(
        number: $checkedConvert('number', (v) => (v as num).toInt()),
        text: $checkedConvert(
          'text',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$NumberCardToJson(NumberCard instance) =>
    <String, dynamic>{
      'number': instance.number,
      'text': instance.text.toJson(),
    };
