// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$IdentityCWProxy {
  Identity provider(LoginProvider provider);

  Identity linkedAt(DateTime linkedAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Identity(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Identity(...).copyWith(id: 12, name: "My name")
  /// ```
  Identity call({LoginProvider provider, DateTime linkedAt});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfIdentity.copyWith(...)` or call `instanceOfIdentity.copyWith.fieldName(value)` for a single field.
class _$IdentityCWProxyImpl implements _$IdentityCWProxy {
  const _$IdentityCWProxyImpl(this._value);

  final Identity _value;

  @override
  Identity provider(LoginProvider provider) => call(provider: provider);

  @override
  Identity linkedAt(DateTime linkedAt) => call(linkedAt: linkedAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Identity(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Identity(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Identity call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? linkedAt = const $CopyWithPlaceholder(),
  }) {
    return Identity(
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as LoginProvider,
      linkedAt: linkedAt == const $CopyWithPlaceholder() || linkedAt == null
          ? _value.linkedAt
          // ignore: cast_nullable_to_non_nullable
          : linkedAt as DateTime,
    );
  }
}

extension $IdentityCopyWith on Identity {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfIdentity.copyWith(...)` or `instanceOfIdentity.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$IdentityCWProxy get copyWith => _$IdentityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Identity _$IdentityFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Identity',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['provider', 'linkedAt']);
    final val = Identity(
      provider: $checkedConvert(
        'provider',
        (v) => $enumDecode(
          _$LoginProviderEnumMap,
          v,
          unknownValue: LoginProvider.unknownDefaultOpenApi,
        ),
      ),
      linkedAt: $checkedConvert('linkedAt', (v) => DateTime.parse(v as String)),
    );
    return val;
  },
);

Map<String, dynamic> _$IdentityToJson(Identity instance) => <String, dynamic>{
  'provider': _$LoginProviderEnumMap[instance.provider]!,
  'linkedAt': instance.linkedAt.toIso8601String(),
};

const _$LoginProviderEnumMap = {
  LoginProvider.kakao: 'kakao',
  LoginProvider.apple: 'apple',
  LoginProvider.line: 'line',
  LoginProvider.google: 'google',
  LoginProvider.unknownDefaultOpenApi: 'unknown_default_open_api',
};
