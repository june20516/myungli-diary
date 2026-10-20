// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AppConfigCWProxy {
  AppConfig minimumVersion(MinimumVersion minimumVersion);

  AppConfig legal(LegalLinks legal);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AppConfig(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AppConfig(...).copyWith(id: 12, name: "My name")
  /// ```
  AppConfig call({MinimumVersion minimumVersion, LegalLinks legal});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAppConfig.copyWith(...)` or call `instanceOfAppConfig.copyWith.fieldName(value)` for a single field.
class _$AppConfigCWProxyImpl implements _$AppConfigCWProxy {
  const _$AppConfigCWProxyImpl(this._value);

  final AppConfig _value;

  @override
  AppConfig minimumVersion(MinimumVersion minimumVersion) =>
      call(minimumVersion: minimumVersion);

  @override
  AppConfig legal(LegalLinks legal) => call(legal: legal);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AppConfig(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AppConfig(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  AppConfig call({
    Object? minimumVersion = const $CopyWithPlaceholder(),
    Object? legal = const $CopyWithPlaceholder(),
  }) {
    return AppConfig(
      minimumVersion:
          minimumVersion == const $CopyWithPlaceholder() ||
              minimumVersion == null
          ? _value.minimumVersion
          // ignore: cast_nullable_to_non_nullable
          : minimumVersion as MinimumVersion,
      legal: legal == const $CopyWithPlaceholder() || legal == null
          ? _value.legal
          // ignore: cast_nullable_to_non_nullable
          : legal as LegalLinks,
    );
  }
}

extension $AppConfigCopyWith on AppConfig {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAppConfig.copyWith(...)` or `instanceOfAppConfig.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AppConfigCWProxy get copyWith => _$AppConfigCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AppConfig', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['minimumVersion', 'legal']);
      final val = AppConfig(
        minimumVersion: $checkedConvert(
          'minimumVersion',
          (v) => MinimumVersion.fromJson(v as Map<String, dynamic>),
        ),
        legal: $checkedConvert(
          'legal',
          (v) => LegalLinks.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
  'minimumVersion': instance.minimumVersion.toJson(),
  'legal': instance.legal.toJson(),
};
