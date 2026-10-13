// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lunar_or_solar_date.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LunarOrSolarDateCWProxy {
  LunarOrSolarDate year(int year);

  LunarOrSolarDate month(int month);

  LunarOrSolarDate day(int day);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarOrSolarDate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarOrSolarDate(...).copyWith(id: 12, name: "My name")
  /// ```
  LunarOrSolarDate call({int year, int month, int day});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLunarOrSolarDate.copyWith(...)` or call `instanceOfLunarOrSolarDate.copyWith.fieldName(value)` for a single field.
class _$LunarOrSolarDateCWProxyImpl implements _$LunarOrSolarDateCWProxy {
  const _$LunarOrSolarDateCWProxyImpl(this._value);

  final LunarOrSolarDate _value;

  @override
  LunarOrSolarDate year(int year) => call(year: year);

  @override
  LunarOrSolarDate month(int month) => call(month: month);

  @override
  LunarOrSolarDate day(int day) => call(day: day);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarOrSolarDate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarOrSolarDate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LunarOrSolarDate call({
    Object? year = const $CopyWithPlaceholder(),
    Object? month = const $CopyWithPlaceholder(),
    Object? day = const $CopyWithPlaceholder(),
  }) {
    return LunarOrSolarDate(
      year: year == const $CopyWithPlaceholder() || year == null
          ? _value.year
          // ignore: cast_nullable_to_non_nullable
          : year as int,
      month: month == const $CopyWithPlaceholder() || month == null
          ? _value.month
          // ignore: cast_nullable_to_non_nullable
          : month as int,
      day: day == const $CopyWithPlaceholder() || day == null
          ? _value.day
          // ignore: cast_nullable_to_non_nullable
          : day as int,
    );
  }
}

extension $LunarOrSolarDateCopyWith on LunarOrSolarDate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLunarOrSolarDate.copyWith(...)` or `instanceOfLunarOrSolarDate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LunarOrSolarDateCWProxy get copyWith => _$LunarOrSolarDateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LunarOrSolarDate _$LunarOrSolarDateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LunarOrSolarDate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['year', 'month', 'day']);
      final val = LunarOrSolarDate(
        year: $checkedConvert('year', (v) => (v as num).toInt()),
        month: $checkedConvert('month', (v) => (v as num).toInt()),
        day: $checkedConvert('day', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$LunarOrSolarDateToJson(LunarOrSolarDate instance) =>
    <String, dynamic>{
      'year': instance.year,
      'month': instance.month,
      'day': instance.day,
    };
