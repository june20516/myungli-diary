// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'birth_time.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BirthTimeCWProxy {
  BirthTime status(BirthTimeStatusEnum status);

  BirthTime value(String? value);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthTime(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthTime(...).copyWith(id: 12, name: "My name")
  /// ```
  BirthTime call({BirthTimeStatusEnum status, String? value});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBirthTime.copyWith(...)` or call `instanceOfBirthTime.copyWith.fieldName(value)` for a single field.
class _$BirthTimeCWProxyImpl implements _$BirthTimeCWProxy {
  const _$BirthTimeCWProxyImpl(this._value);

  final BirthTime _value;

  @override
  BirthTime status(BirthTimeStatusEnum status) => call(status: status);

  @override
  BirthTime value(String? value) => call(value: value);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BirthTime(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BirthTime(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BirthTime call({
    Object? status = const $CopyWithPlaceholder(),
    Object? value = const $CopyWithPlaceholder(),
  }) {
    return BirthTime(
      status: status == const $CopyWithPlaceholder() || status == null
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as BirthTimeStatusEnum,
      value: value == const $CopyWithPlaceholder()
          ? _value.value
          // ignore: cast_nullable_to_non_nullable
          : value as String?,
    );
  }
}

extension $BirthTimeCopyWith on BirthTime {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBirthTime.copyWith(...)` or `instanceOfBirthTime.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BirthTimeCWProxy get copyWith => _$BirthTimeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BirthTime _$BirthTimeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BirthTime', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status']);
      final val = BirthTime(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$BirthTimeStatusEnumEnumMap, v),
        ),
        value: $checkedConvert('value', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$BirthTimeToJson(BirthTime instance) => <String, dynamic>{
  'status': _$BirthTimeStatusEnumEnumMap[instance.status]!,
  'value': ?instance.value,
};

const _$BirthTimeStatusEnumEnumMap = {
  BirthTimeStatusEnum.known: 'known',
  BirthTimeStatusEnum.unknown: 'unknown',
};
