// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'birth_place.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BirthPlaceCWProxy {
  BirthPlace status(BirthPlaceStatusEnum status);

  BirthPlace cityId(String? cityId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthPlace(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthPlace(...).copyWith(id: 12, name: "My name")
  /// ```
  BirthPlace call({BirthPlaceStatusEnum status, String? cityId});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBirthPlace.copyWith(...)` or call `instanceOfBirthPlace.copyWith.fieldName(value)` for a single field.
class _$BirthPlaceCWProxyImpl implements _$BirthPlaceCWProxy {
  const _$BirthPlaceCWProxyImpl(this._value);

  final BirthPlace _value;

  @override
  BirthPlace status(BirthPlaceStatusEnum status) => call(status: status);

  @override
  BirthPlace cityId(String? cityId) => call(cityId: cityId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthPlace(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthPlace(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BirthPlace call({
    Object? status = const $CopyWithPlaceholder(),
    Object? cityId = const $CopyWithPlaceholder(),
  }) {
    return BirthPlace(
      status: status == const $CopyWithPlaceholder() || status == null
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as BirthPlaceStatusEnum,
      cityId: cityId == const $CopyWithPlaceholder()
          ? _value.cityId
          // ignore: cast_nullable_to_non_nullable
          : cityId as String?,
    );
  }
}

extension $BirthPlaceCopyWith on BirthPlace {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBirthPlace.copyWith(...)` or `instanceOfBirthPlace.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BirthPlaceCWProxy get copyWith => _$BirthPlaceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BirthPlace _$BirthPlaceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BirthPlace', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status']);
      final val = BirthPlace(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$BirthPlaceStatusEnumEnumMap, v),
        ),
        cityId: $checkedConvert('cityId', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$BirthPlaceToJson(BirthPlace instance) =>
    <String, dynamic>{
      'status': _$BirthPlaceStatusEnumEnumMap[instance.status]!,
      'cityId': ?instance.cityId,
    };

const _$BirthPlaceStatusEnumEnumMap = {
  BirthPlaceStatusEnum.notAsked: 'not_asked',
  BirthPlaceStatusEnum.skipped: 'skipped',
  BirthPlaceStatusEnum.city: 'city',
};
