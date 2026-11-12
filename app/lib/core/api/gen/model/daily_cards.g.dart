// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_cards.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DailyCardsCWProxy {
  DailyCards color(ColorCard color);

  DailyCards secondColor(ColorCard? secondColor);

  DailyCards direction(DirectionCard direction);

  DailyCards number(NumberCard number);

  DailyCards focusTime(FocusTimeCard focusTime);

  DailyCards nightFocusTime(FocusTimeCard? nightFocusTime);

  DailyCards previousNightFocusTime(FocusTimeCard? previousNightFocusTime);

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
    ColorCard? secondColor,
    DirectionCard direction,
    NumberCard number,
    FocusTimeCard focusTime,
    FocusTimeCard? nightFocusTime,
    FocusTimeCard? previousNightFocusTime,
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
  DailyCards secondColor(ColorCard? secondColor) =>
      call(secondColor: secondColor);

  @override
  DailyCards direction(DirectionCard direction) => call(direction: direction);

  @override
  DailyCards number(NumberCard number) => call(number: number);

  @override
  DailyCards focusTime(FocusTimeCard focusTime) => call(focusTime: focusTime);

  @override
  DailyCards nightFocusTime(FocusTimeCard? nightFocusTime) =>
      call(nightFocusTime: nightFocusTime);

  @override
  DailyCards previousNightFocusTime(FocusTimeCard? previousNightFocusTime) =>
      call(previousNightFocusTime: previousNightFocusTime);

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
    Object? secondColor = const $CopyWithPlaceholder(),
    Object? direction = const $CopyWithPlaceholder(),
    Object? number = const $CopyWithPlaceholder(),
    Object? focusTime = const $CopyWithPlaceholder(),
    Object? nightFocusTime = const $CopyWithPlaceholder(),
    Object? previousNightFocusTime = const $CopyWithPlaceholder(),
  }) {
    return DailyCards(
      color: color == const $CopyWithPlaceholder() || color == null
          ? _value.color
          // ignore: cast_nullable_to_non_nullable
          : color as ColorCard,
      secondColor: secondColor == const $CopyWithPlaceholder()
          ? _value.secondColor
          // ignore: cast_nullable_to_non_nullable
          : secondColor as ColorCard?,
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
      nightFocusTime: nightFocusTime == const $CopyWithPlaceholder()
          ? _value.nightFocusTime
          // ignore: cast_nullable_to_non_nullable
          : nightFocusTime as FocusTimeCard?,
      previousNightFocusTime:
          previousNightFocusTime == const $CopyWithPlaceholder()
          ? _value.previousNightFocusTime
          // ignore: cast_nullable_to_non_nullable
          : previousNightFocusTime as FocusTimeCard?,
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

DailyCards _$DailyCardsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DailyCards', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['color', 'direction', 'number', 'focusTime'],
  );
  final val = DailyCards(
    color: $checkedConvert(
      'color',
      (v) => ColorCard.fromJson(v as Map<String, dynamic>),
    ),
    secondColor: $checkedConvert(
      'secondColor',
      (v) => v == null ? null : ColorCard.fromJson(v as Map<String, dynamic>),
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
    nightFocusTime: $checkedConvert(
      'nightFocusTime',
      (v) =>
          v == null ? null : FocusTimeCard.fromJson(v as Map<String, dynamic>),
    ),
    previousNightFocusTime: $checkedConvert(
      'previousNightFocusTime',
      (v) =>
          v == null ? null : FocusTimeCard.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$DailyCardsToJson(DailyCards instance) =>
    <String, dynamic>{
      'color': instance.color.toJson(),
      'secondColor': ?instance.secondColor?.toJson(),
      'direction': instance.direction.toJson(),
      'number': instance.number.toJson(),
      'focusTime': instance.focusTime.toJson(),
      'nightFocusTime': ?instance.nightFocusTime?.toJson(),
      'previousNightFocusTime': ?instance.previousNightFocusTime?.toJson(),
    };
