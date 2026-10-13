// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direction_card.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DirectionCardCWProxy {
  DirectionCard direction(Direction direction);

  DirectionCard text(SlotText text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DirectionCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DirectionCard(...).copyWith(id: 12, name: "My name")
  /// ```
  DirectionCard call({Direction direction, SlotText text});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDirectionCard.copyWith(...)` or call `instanceOfDirectionCard.copyWith.fieldName(value)` for a single field.
class _$DirectionCardCWProxyImpl implements _$DirectionCardCWProxy {
  const _$DirectionCardCWProxyImpl(this._value);

  final DirectionCard _value;

  @override
  DirectionCard direction(Direction direction) => call(direction: direction);

  @override
  DirectionCard text(SlotText text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DirectionCard(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DirectionCard(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DirectionCard call({
    Object? direction = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
  }) {
    return DirectionCard(
      direction: direction == const $CopyWithPlaceholder() || direction == null
          ? _value.direction
          // ignore: cast_nullable_to_non_nullable
          : direction as Direction,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as SlotText,
    );
  }
}

extension $DirectionCardCopyWith on DirectionCard {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDirectionCard.copyWith(...)` or `instanceOfDirectionCard.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DirectionCardCWProxy get copyWith => _$DirectionCardCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DirectionCard _$DirectionCardFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DirectionCard', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['direction', 'text']);
      final val = DirectionCard(
        direction: $checkedConvert(
          'direction',
          (v) => $enumDecode(_$DirectionEnumMap, v),
        ),
        text: $checkedConvert(
          'text',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DirectionCardToJson(DirectionCard instance) =>
    <String, dynamic>{
      'direction': _$DirectionEnumMap[instance.direction]!,
      'text': instance.text.toJson(),
    };

const _$DirectionEnumMap = {
  Direction.n: 'n',
  Direction.ne: 'ne',
  Direction.e: 'e',
  Direction.se: 'se',
  Direction.s: 's',
  Direction.sw: 'sw',
  Direction.w: 'w',
  Direction.nw: 'nw',
};
