// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_cards.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DailyCardsCWProxy {
  DailyCards color(ColorCard color);

  DailyCards direction(DirectionCard direction);

  DailyCards number(NumberCard number);

  DailyCards focusTime(FocusTimeCard focusTime);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DailyCards(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DailyCards(...).copyWith(id: 12, name: "My name")
  /// ```
  DailyCards call({
    ColorCard color,
    DirectionCard direction,
    NumberCard number,
    FocusTimeCard focusTime,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDailyCards.copyWith(...)` or call `instanceOfDailyCards.copyWith.fieldName(value)` for a single field.
class _$DailyCardsCWProxyImpl implements _$DailyCardsCWProxy {
  const _$DailyCardsCWProxyImpl(this._value);

  final DailyCards _value;

  @override
  DailyCards color(ColorCard color) => call(color: color);

  @override
  DailyCards direction(DirectionCard direction) => call(direction: direction);

  @override
  DailyCards number(NumberCard number) => call(number: number);

  @override
  DailyCards focusTime(FocusTimeCard focusTime) => call(focusTime: focusTime);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DailyCards(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DailyCards(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DailyCards call({
    Object? color = const $CopyWithPlaceholder(),
    Object? direction = const $CopyWithPlaceholder(),
    Object? number = const $CopyWithPlaceholder(),
    Object? focusTime = const $CopyWithPlaceholder(),
  }) {
    return DailyCards(
      color: color == const $CopyWithPlaceholder() || color == null
          ? _value.color
          // ignore: cast_nullable_to_non_nullable
          : color as ColorCard,
      direction: direction == const $CopyWithPlaceholder() || direction == null
          ? _value.direction
          // ignore: cast_nullable_to_non_nullable
          : direction as DirectionCard,
      number: number == const $CopyWithPlaceholder() || number == null
          ? _value.number
          // ignore: cast_nullable_to_non_nullable
          : number as NumberCard,
      focusTime: focusTime == const $CopyWithPlaceholder() || focusTime == null
          ? _value.focusTime
          // ignore: cast_nullable_to_non_nullable
          : focusTime as FocusTimeCard,
    );
  }
}

extension $DailyCardsCopyWith on DailyCards {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDailyCards.copyWith(...)` or `instanceOfDailyCards.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DailyCardsCWProxy get copyWith => _$DailyCardsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyCards _$DailyCardsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DailyCards', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['color', 'direction', 'number', 'focusTime'],
      );
      final val = DailyCards(
        color: $checkedConvert(
          'color',
          (v) => ColorCard.fromJson(v as Map<String, dynamic>),
        ),
        direction: $checkedConvert(
          'direction',
          (v) => DirectionCard.fromJson(v as Map<String, dynamic>),
        ),
        number: $checkedConvert(
          'number',
          (v) => NumberCard.fromJson(v as Map<String, dynamic>),
        ),
        focusTime: $checkedConvert(
          'focusTime',
          (v) => FocusTimeCard.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DailyCardsToJson(DailyCards instance) =>
    <String, dynamic>{
      'color': instance.color.toJson(),
      'direction': instance.direction.toJson(),
      'number': instance.number.toJson(),
      'focusTime': instance.focusTime.toJson(),
    };
