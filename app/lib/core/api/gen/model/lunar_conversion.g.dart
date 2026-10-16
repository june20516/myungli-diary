// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lunar_conversion.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LunarConversionCWProxy {
  LunarConversion solarDate(String solarDate);

  LunarConversion monthHasLeap(bool monthHasLeap);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarConversion(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarConversion(...).copyWith(id: 12, name: "My name")
  /// ```
  LunarConversion call({String solarDate, bool monthHasLeap});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLunarConversion.copyWith(...)` or call `instanceOfLunarConversion.copyWith.fieldName(value)` for a single field.
class _$LunarConversionCWProxyImpl implements _$LunarConversionCWProxy {
  const _$LunarConversionCWProxyImpl(this._value);

  final LunarConversion _value;

  @override
  LunarConversion solarDate(String solarDate) => call(solarDate: solarDate);

  @override
  LunarConversion monthHasLeap(bool monthHasLeap) =>
      call(monthHasLeap: monthHasLeap);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LunarConversion(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LunarConversion(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LunarConversion call({
    Object? solarDate = const $CopyWithPlaceholder(),
    Object? monthHasLeap = const $CopyWithPlaceholder(),
  }) {
    return LunarConversion(
      solarDate: solarDate == const $CopyWithPlaceholder() || solarDate == null
          ? _value.solarDate
          // ignore: cast_nullable_to_non_nullable
          : solarDate as String,
      monthHasLeap:
          monthHasLeap == const $CopyWithPlaceholder() || monthHasLeap == null
          ? _value.monthHasLeap
          // ignore: cast_nullable_to_non_nullable
          : monthHasLeap as bool,
    );
  }
}

extension $LunarConversionCopyWith on LunarConversion {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLunarConversion.copyWith(...)` or `instanceOfLunarConversion.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LunarConversionCWProxy get copyWith => _$LunarConversionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LunarConversion _$LunarConversionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LunarConversion', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['solarDate', 'monthHasLeap']);
      final val = LunarConversion(
        solarDate: $checkedConvert('solarDate', (v) => v as String),
        monthHasLeap: $checkedConvert('monthHasLeap', (v) => v as bool),
      );
      return val;
    });

Map<String, dynamic> _$LunarConversionToJson(LunarConversion instance) =>
    <String, dynamic>{
      'solarDate': instance.solarDate,
      'monthHasLeap': instance.monthHasLeap,
    };
