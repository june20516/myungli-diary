// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_pillars.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ChartPillarsCWProxy {
  ChartPillars year(Pillar year);

  ChartPillars month(Pillar month);

  ChartPillars day(Pillar day);

  ChartPillars hour(Pillar? hour);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ChartPillars(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ChartPillars(...).copyWith(id: 12, name: "My name")
  /// ```
  ChartPillars call({Pillar year, Pillar month, Pillar day, Pillar? hour});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfChartPillars.copyWith(...)` or call `instanceOfChartPillars.copyWith.fieldName(value)` for a single field.
class _$ChartPillarsCWProxyImpl implements _$ChartPillarsCWProxy {
  const _$ChartPillarsCWProxyImpl(this._value);

  final ChartPillars _value;

  @override
  ChartPillars year(Pillar year) => call(year: year);

  @override
  ChartPillars month(Pillar month) => call(month: month);

  @override
  ChartPillars day(Pillar day) => call(day: day);

  @override
  ChartPillars hour(Pillar? hour) => call(hour: hour);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ChartPillars(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ChartPillars(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ChartPillars call({
    Object? year = const $CopyWithPlaceholder(),
    Object? month = const $CopyWithPlaceholder(),
    Object? day = const $CopyWithPlaceholder(),
    Object? hour = const $CopyWithPlaceholder(),
  }) {
    return ChartPillars(
      year: year == const $CopyWithPlaceholder() || year == null
          ? _value.year
          // ignore: cast_nullable_to_non_nullable
          : year as Pillar,
      month: month == const $CopyWithPlaceholder() || month == null
          ? _value.month
          // ignore: cast_nullable_to_non_nullable
          : month as Pillar,
      day: day == const $CopyWithPlaceholder() || day == null
          ? _value.day
          // ignore: cast_nullable_to_non_nullable
          : day as Pillar,
      hour: hour == const $CopyWithPlaceholder()
          ? _value.hour
          // ignore: cast_nullable_to_non_nullable
          : hour as Pillar?,
    );
  }
}

extension $ChartPillarsCopyWith on ChartPillars {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfChartPillars.copyWith(...)` or `instanceOfChartPillars.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ChartPillarsCWProxy get copyWith => _$ChartPillarsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChartPillars _$ChartPillarsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ChartPillars', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['year', 'month', 'day']);
      final val = ChartPillars(
        year: $checkedConvert(
          'year',
          (v) => Pillar.fromJson(v as Map<String, dynamic>),
        ),
        month: $checkedConvert(
          'month',
          (v) => Pillar.fromJson(v as Map<String, dynamic>),
        ),
        day: $checkedConvert(
          'day',
          (v) => Pillar.fromJson(v as Map<String, dynamic>),
        ),
        hour: $checkedConvert(
          'hour',
          (v) => v == null ? null : Pillar.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ChartPillarsToJson(ChartPillars instance) =>
    <String, dynamic>{
      'year': instance.year.toJson(),
      'month': instance.month.toJson(),
      'day': instance.day.toJson(),
      'hour': ?instance.hour?.toJson(),
    };
