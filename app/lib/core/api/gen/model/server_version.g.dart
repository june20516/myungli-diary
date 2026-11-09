// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_version.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ServerVersionCWProxy {
  ServerVersion supportedRulesetVersion(String supportedRulesetVersion);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ServerVersion(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ServerVersion(...).copyWith(id: 12, name: "My name")
  /// ```
  ServerVersion call({String supportedRulesetVersion});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfServerVersion.copyWith(...)` or call `instanceOfServerVersion.copyWith.fieldName(value)` for a single field.
class _$ServerVersionCWProxyImpl implements _$ServerVersionCWProxy {
  const _$ServerVersionCWProxyImpl(this._value);

  final ServerVersion _value;

  @override
  ServerVersion supportedRulesetVersion(String supportedRulesetVersion) =>
      call(supportedRulesetVersion: supportedRulesetVersion);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ServerVersion(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ServerVersion(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ServerVersion call({
    Object? supportedRulesetVersion = const $CopyWithPlaceholder(),
  }) {
    return ServerVersion(
      supportedRulesetVersion:
          supportedRulesetVersion == const $CopyWithPlaceholder() ||
              supportedRulesetVersion == null
          ? _value.supportedRulesetVersion
          // ignore: cast_nullable_to_non_nullable
          : supportedRulesetVersion as String,
    );
  }
}

extension $ServerVersionCopyWith on ServerVersion {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfServerVersion.copyWith(...)` or `instanceOfServerVersion.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ServerVersionCWProxy get copyWith => _$ServerVersionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerVersion _$ServerVersionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ServerVersion', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['supportedRulesetVersion']);
      final val = ServerVersion(
        supportedRulesetVersion: $checkedConvert(
          'supportedRulesetVersion',
          (v) => v as String,
        ),
      );
      return val;
    });

Map<String, dynamic> _$ServerVersionToJson(ServerVersion instance) =>
    <String, dynamic>{
      'supportedRulesetVersion': instance.supportedRulesetVersion,
    };
