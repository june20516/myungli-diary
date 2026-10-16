// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CityCWProxy {
  City id(String id);

  City name(String name);

  City country(String country);

  City countryName(String countryName);

  City regionName(String? regionName);

  City timezone(String timezone);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `City(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// City(...).copyWith(id: 12, name: "My name")
  /// ```
  City call({
    String id,
    String name,
    String country,
    String countryName,
    String? regionName,
    String timezone,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCity.copyWith(...)` or call `instanceOfCity.copyWith.fieldName(value)` for a single field.
class _$CityCWProxyImpl implements _$CityCWProxy {
  const _$CityCWProxyImpl(this._value);

  final City _value;

  @override
  City id(String id) => call(id: id);

  @override
  City name(String name) => call(name: name);

  @override
  City country(String country) => call(country: country);

  @override
  City countryName(String countryName) => call(countryName: countryName);

  @override
  City regionName(String? regionName) => call(regionName: regionName);

  @override
  City timezone(String timezone) => call(timezone: timezone);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `City(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// City(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  City call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? country = const $CopyWithPlaceholder(),
    Object? countryName = const $CopyWithPlaceholder(),
    Object? regionName = const $CopyWithPlaceholder(),
    Object? timezone = const $CopyWithPlaceholder(),
  }) {
    return City(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      country: country == const $CopyWithPlaceholder() || country == null
          ? _value.country
          // ignore: cast_nullable_to_non_nullable
          : country as String,
      countryName:
          countryName == const $CopyWithPlaceholder() || countryName == null
          ? _value.countryName
          // ignore: cast_nullable_to_non_nullable
          : countryName as String,
      regionName: regionName == const $CopyWithPlaceholder()
          ? _value.regionName
          // ignore: cast_nullable_to_non_nullable
          : regionName as String?,
      timezone: timezone == const $CopyWithPlaceholder() || timezone == null
          ? _value.timezone
          // ignore: cast_nullable_to_non_nullable
          : timezone as String,
    );
  }
}

extension $CityCopyWith on City {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCity.copyWith(...)` or `instanceOfCity.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CityCWProxy get copyWith => _$CityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

City _$CityFromJson(Map<String, dynamic> json) => $checkedCreate('City', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    requiredKeys: const ['id', 'name', 'country', 'countryName', 'timezone'],
  );
  final val = City(
    id: $checkedConvert('id', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    country: $checkedConvert('country', (v) => v as String),
    countryName: $checkedConvert('countryName', (v) => v as String),
    regionName: $checkedConvert('regionName', (v) => v as String?),
    timezone: $checkedConvert('timezone', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CityToJson(City instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'country': instance.country,
  'countryName': instance.countryName,
  'regionName': ?instance.regionName,
  'timezone': instance.timezone,
};
