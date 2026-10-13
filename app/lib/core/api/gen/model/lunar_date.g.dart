// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lunar_date.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LunarDateCWProxy {
  LunarDate month(int month);

  LunarDate day(int day);

  LunarDate isLeapMonth(bool isLeapMonth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarDate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarDate(...).copyWith(id: 12, name: "My name")
  /// ```
  LunarDate call({int month, int day, bool isLeapMonth});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLunarDate.copyWith(...)` or call `instanceOfLunarDate.copyWith.fieldName(value)` for a single field.
class _$LunarDateCWProxyImpl implements _$LunarDateCWProxy {
  const _$LunarDateCWProxyImpl(this._value);

  final LunarDate _value;

  @override
  LunarDate month(int month) => call(month: month);

  @override
  LunarDate day(int day) => call(day: day);

  @override
  LunarDate isLeapMonth(bool isLeapMonth) => call(isLeapMonth: isLeapMonth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarDate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarDate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LunarDate call({
    Object? month = const $CopyWithPlaceholder(),
    Object? day = const $CopyWithPlaceholder(),
    Object? isLeapMonth = const $CopyWithPlaceholder(),
  }) {
    return LunarDate(
      month: month == const $CopyWithPlaceholder() || month == null
          ? _value.month
          // ignore: cast_nullable_to_non_nullable
          : month as int,
      day: day == const $CopyWithPlaceholder() || day == null
          ? _value.day
          // ignore: cast_nullable_to_non_nullable
          : day as int,
      isLeapMonth:
          isLeapMonth == const $CopyWithPlaceholder() || isLeapMonth == null
          ? _value.isLeapMonth
          // ignore: cast_nullable_to_non_nullable
          : isLeapMonth as bool,
    );
  }
}

extension $LunarDateCopyWith on LunarDate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLunarDate.copyWith(...)` or `instanceOfLunarDate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LunarDateCWProxy get copyWith => _$LunarDateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LunarDate _$LunarDateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LunarDate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['month', 'day', 'isLeapMonth']);
      final val = LunarDate(
        month: $checkedConvert('month', (v) => (v as num).toInt()),
        day: $checkedConvert('day', (v) => (v as num).toInt()),
        isLeapMonth: $checkedConvert('isLeapMonth', (v) => v as bool),
      );
      return val;
    });

Map<String, dynamic> _$LunarDateToJson(LunarDate instance) => <String, dynamic>{
  'month': instance.month,
  'day': instance.day,
  'isLeapMonth': instance.isLeapMonth,
};
