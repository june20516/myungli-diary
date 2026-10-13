// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_time_card.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FocusTimeCardCWProxy {
  FocusTimeCard picks(List<FocusSlot> picks);

  FocusTimeCard fallback(bool fallback);

  FocusTimeCard text(SlotText text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FocusTimeCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FocusTimeCard(...).copyWith(id: 12, name: "My name")
  /// ```
  FocusTimeCard call({List<FocusSlot> picks, bool fallback, SlotText text});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfFocusTimeCard.copyWith(...)` or call `instanceOfFocusTimeCard.copyWith.fieldName(value)` for a single field.
class _$FocusTimeCardCWProxyImpl implements _$FocusTimeCardCWProxy {
  const _$FocusTimeCardCWProxyImpl(this._value);

  final FocusTimeCard _value;

  @override
  FocusTimeCard picks(List<FocusSlot> picks) => call(picks: picks);

  @override
  FocusTimeCard fallback(bool fallback) => call(fallback: fallback);

  @override
  FocusTimeCard text(SlotText text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FocusTimeCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FocusTimeCard(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  FocusTimeCard call({
    Object? picks = const $CopyWithPlaceholder(),
    Object? fallback = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
  }) {
    return FocusTimeCard(
      picks: picks == const $CopyWithPlaceholder() || picks == null
          ? _value.picks
          // ignore: cast_nullable_to_non_nullable
          : picks as List<FocusSlot>,
      fallback: fallback == const $CopyWithPlaceholder() || fallback == null
          ? _value.fallback
          // ignore: cast_nullable_to_non_nullable
          : fallback as bool,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as SlotText,
    );
  }
}

extension $FocusTimeCardCopyWith on FocusTimeCard {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfFocusTimeCard.copyWith(...)` or `instanceOfFocusTimeCard.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FocusTimeCardCWProxy get copyWith => _$FocusTimeCardCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FocusTimeCard _$FocusTimeCardFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FocusTimeCard', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['picks', 'fallback', 'text']);
      final val = FocusTimeCard(
        picks: $checkedConvert(
          'picks',
          (v) => (v as List<dynamic>)
              .map((e) => FocusSlot.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        fallback: $checkedConvert('fallback', (v) => v as bool),
        text: $checkedConvert(
          'text',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FocusTimeCardToJson(FocusTimeCard instance) =>
    <String, dynamic>{
      'picks': instance.picks.map((e) => e.toJson()).toList(),
      'fallback': instance.fallback,
      'text': instance.text.toJson(),
    };
