// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_kind_count.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DayKindCountCWProxy {
  DayKindCount dayKind(DayKind dayKind);

  DayKindCount days(int days);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DayKindCount(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DayKindCount(...).copyWith(id: 12, name: "My name")
  /// ```
  DayKindCount call({DayKind dayKind, int days});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDayKindCount.copyWith(...)` or call `instanceOfDayKindCount.copyWith.fieldName(value)` for a single field.
class _$DayKindCountCWProxyImpl implements _$DayKindCountCWProxy {
  const _$DayKindCountCWProxyImpl(this._value);

  final DayKindCount _value;

  @override
  DayKindCount dayKind(DayKind dayKind) => call(dayKind: dayKind);

  @override
  DayKindCount days(int days) => call(days: days);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DayKindCount(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DayKindCount(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DayKindCount call({
    Object? dayKind = const $CopyWithPlaceholder(),
    Object? days = const $CopyWithPlaceholder(),
  }) {
    return DayKindCount(
      dayKind: dayKind == const $CopyWithPlaceholder() || dayKind == null
          ? _value.dayKind
          // ignore: cast_nullable_to_non_nullable
          : dayKind as DayKind,
      days: days == const $CopyWithPlaceholder() || days == null
          ? _value.days
          // ignore: cast_nullable_to_non_nullable
          : days as int,
    );
  }
}

extension $DayKindCountCopyWith on DayKindCount {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDayKindCount.copyWith(...)` or `instanceOfDayKindCount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DayKindCountCWProxy get copyWith => _$DayKindCountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DayKindCount _$DayKindCountFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DayKindCount', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['dayKind', 'days']);
      final val = DayKindCount(
        dayKind: $checkedConvert(
          'dayKind',
          (v) => $enumDecode(_$DayKindEnumMap, v),
        ),
        days: $checkedConvert('days', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$DayKindCountToJson(DayKindCount instance) =>
    <String, dynamic>{
      'dayKind': _$DayKindEnumMap[instance.dayKind]!,
      'days': instance.days,
    };

const _$DayKindEnumMap = {
  DayKind.gwiinDay: 'gwiin_day',
  DayKind.yongsinDay: 'yongsin_day',
  DayKind.gisinDay: 'gisin_day',
  DayKind.ordinaryDay: 'ordinary_day',
};
