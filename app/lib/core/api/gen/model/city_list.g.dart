// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CityListCWProxy {
  CityList dataVersion(String dataVersion);

  CityList items(List<City> items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CityList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CityList(...).copyWith(id: 12, name: "My name")
  /// ```
  CityList call({String dataVersion, List<City> items});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCityList.copyWith(...)` or call `instanceOfCityList.copyWith.fieldName(value)` for a single field.
class _$CityListCWProxyImpl implements _$CityListCWProxy {
  const _$CityListCWProxyImpl(this._value);

  final CityList _value;

  @override
  CityList dataVersion(String dataVersion) => call(dataVersion: dataVersion);

  @override
  CityList items(List<City> items) => call(items: items);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CityList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CityList(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CityList call({
    Object? dataVersion = const $CopyWithPlaceholder(),
    Object? items = const $CopyWithPlaceholder(),
  }) {
    return CityList(
      dataVersion:
          dataVersion == const $CopyWithPlaceholder() || dataVersion == null
          ? _value.dataVersion
          // ignore: cast_nullable_to_non_nullable
          : dataVersion as String,
      items: items == const $CopyWithPlaceholder() || items == null
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<City>,
    );
  }
}

extension $CityListCopyWith on CityList {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCityList.copyWith(...)` or `instanceOfCityList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CityListCWProxy get copyWith => _$CityListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CityList _$CityListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CityList', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['dataVersion', 'items']);
      final val = CityList(
        dataVersion: $checkedConvert('dataVersion', (v) => v as String),
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => City.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CityListToJson(CityList instance) => <String, dynamic>{
  'dataVersion': instance.dataVersion,
  'items': instance.items.map((e) => e.toJson()).toList(),
};
