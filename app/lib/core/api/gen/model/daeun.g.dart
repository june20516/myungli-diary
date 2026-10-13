// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daeun.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DaeunCWProxy {
  Daeun forward(bool forward);

  Daeun startYears(int startYears);

  Daeun startMonths(int startMonths);

  Daeun periods(List<DaeunPeriod> periods);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Daeun(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Daeun(...).copyWith(id: 12, name: "My name")
  /// ```
  Daeun call({
    bool forward,
    int startYears,
    int startMonths,
    List<DaeunPeriod> periods,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDaeun.copyWith(...)` or call `instanceOfDaeun.copyWith.fieldName(value)` for a single field.
class _$DaeunCWProxyImpl implements _$DaeunCWProxy {
  const _$DaeunCWProxyImpl(this._value);

  final Daeun _value;

  @override
  Daeun forward(bool forward) => call(forward: forward);

  @override
  Daeun startYears(int startYears) => call(startYears: startYears);

  @override
  Daeun startMonths(int startMonths) => call(startMonths: startMonths);

  @override
  Daeun periods(List<DaeunPeriod> periods) => call(periods: periods);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Daeun(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Daeun(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Daeun call({
    Object? forward = const $CopyWithPlaceholder(),
    Object? startYears = const $CopyWithPlaceholder(),
    Object? startMonths = const $CopyWithPlaceholder(),
    Object? periods = const $CopyWithPlaceholder(),
  }) {
    return Daeun(
      forward: forward == const $CopyWithPlaceholder() || forward == null
          ? _value.forward
          // ignore: cast_nullable_to_non_nullable
          : forward as bool,
      startYears:
          startYears == const $CopyWithPlaceholder() || startYears == null
          ? _value.startYears
          // ignore: cast_nullable_to_non_nullable
          : startYears as int,
      startMonths:
          startMonths == const $CopyWithPlaceholder() || startMonths == null
          ? _value.startMonths
          // ignore: cast_nullable_to_non_nullable
          : startMonths as int,
      periods: periods == const $CopyWithPlaceholder() || periods == null
          ? _value.periods
          // ignore: cast_nullable_to_non_nullable
          : periods as List<DaeunPeriod>,
    );
  }
}

extension $DaeunCopyWith on Daeun {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDaeun.copyWith(...)` or `instanceOfDaeun.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DaeunCWProxy get copyWith => _$DaeunCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Daeun _$DaeunFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Daeun', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['forward', 'startYears', 'startMonths', 'periods'],
      );
      final val = Daeun(
        forward: $checkedConvert('forward', (v) => v as bool),
        startYears: $checkedConvert('startYears', (v) => (v as num).toInt()),
        startMonths: $checkedConvert('startMonths', (v) => (v as num).toInt()),
        periods: $checkedConvert(
          'periods',
          (v) => (v as List<dynamic>)
              .map((e) => DaeunPeriod.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DaeunToJson(Daeun instance) => <String, dynamic>{
  'forward': instance.forward,
  'startYears': instance.startYears,
  'startMonths': instance.startMonths,
  'periods': instance.periods.map((e) => e.toJson()).toList(),
};
