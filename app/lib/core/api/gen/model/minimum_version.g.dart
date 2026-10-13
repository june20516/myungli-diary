// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minimum_version.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MinimumVersionCWProxy {
  MinimumVersion ios(String ios);

  MinimumVersion android(String android);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MinimumVersion(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MinimumVersion(...).copyWith(id: 12, name: "My name")
  /// ```
  MinimumVersion call({String ios, String android});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMinimumVersion.copyWith(...)` or call `instanceOfMinimumVersion.copyWith.fieldName(value)` for a single field.
class _$MinimumVersionCWProxyImpl implements _$MinimumVersionCWProxy {
  const _$MinimumVersionCWProxyImpl(this._value);

  final MinimumVersion _value;

  @override
  MinimumVersion ios(String ios) => call(ios: ios);

  @override
  MinimumVersion android(String android) => call(android: android);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MinimumVersion(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MinimumVersion(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MinimumVersion call({
    Object? ios = const $CopyWithPlaceholder(),
    Object? android = const $CopyWithPlaceholder(),
  }) {
    return MinimumVersion(
      ios: ios == const $CopyWithPlaceholder() || ios == null
          ? _value.ios
          // ignore: cast_nullable_to_non_nullable
          : ios as String,
      android: android == const $CopyWithPlaceholder() || android == null
          ? _value.android
          // ignore: cast_nullable_to_non_nullable
          : android as String,
    );
  }
}

extension $MinimumVersionCopyWith on MinimumVersion {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMinimumVersion.copyWith(...)` or `instanceOfMinimumVersion.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MinimumVersionCWProxy get copyWith => _$MinimumVersionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MinimumVersion _$MinimumVersionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MinimumVersion', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['ios', 'android']);
      final val = MinimumVersion(
        ios: $checkedConvert('ios', (v) => v as String),
        android: $checkedConvert('android', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$MinimumVersionToJson(MinimumVersion instance) =>
    <String, dynamic>{'ios': instance.ios, 'android': instance.android};
