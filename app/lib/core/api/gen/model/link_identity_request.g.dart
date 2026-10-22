// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_identity_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LinkIdentityRequestCWProxy {
  LinkIdentityRequest idToken(String? idToken);

  LinkIdentityRequest authorizationCode(String? authorizationCode);

  LinkIdentityRequest exchangeCode(String? exchangeCode);

  LinkIdentityRequest nonce(String nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LinkIdentityRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LinkIdentityRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  LinkIdentityRequest call({
    String? idToken,
    String? authorizationCode,
    String? exchangeCode,
    String nonce,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLinkIdentityRequest.copyWith(...)` or call `instanceOfLinkIdentityRequest.copyWith.fieldName(value)` for a single field.
class _$LinkIdentityRequestCWProxyImpl implements _$LinkIdentityRequestCWProxy {
  const _$LinkIdentityRequestCWProxyImpl(this._value);

  final LinkIdentityRequest _value;

  @override
  LinkIdentityRequest idToken(String? idToken) => call(idToken: idToken);

  @override
  LinkIdentityRequest authorizationCode(String? authorizationCode) =>
      call(authorizationCode: authorizationCode);

  @override
  LinkIdentityRequest exchangeCode(String? exchangeCode) =>
      call(exchangeCode: exchangeCode);

  @override
  LinkIdentityRequest nonce(String nonce) => call(nonce: nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LinkIdentityRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LinkIdentityRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LinkIdentityRequest call({
    Object? idToken = const $CopyWithPlaceholder(),
    Object? authorizationCode = const $CopyWithPlaceholder(),
    Object? exchangeCode = const $CopyWithPlaceholder(),
    Object? nonce = const $CopyWithPlaceholder(),
  }) {
    return LinkIdentityRequest(
      idToken: idToken == const $CopyWithPlaceholder()
          ? _value.idToken
          // ignore: cast_nullable_to_non_nullable
          : idToken as String?,
      authorizationCode: authorizationCode == const $CopyWithPlaceholder()
          ? _value.authorizationCode
          // ignore: cast_nullable_to_non_nullable
          : authorizationCode as String?,
      exchangeCode: exchangeCode == const $CopyWithPlaceholder()
          ? _value.exchangeCode
          // ignore: cast_nullable_to_non_nullable
          : exchangeCode as String?,
      nonce: nonce == const $CopyWithPlaceholder() || nonce == null
          ? _value.nonce
          // ignore: cast_nullable_to_non_nullable
          : nonce as String,
    );
  }
}

extension $LinkIdentityRequestCopyWith on LinkIdentityRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLinkIdentityRequest.copyWith(...)` or `instanceOfLinkIdentityRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LinkIdentityRequestCWProxy get copyWith =>
      _$LinkIdentityRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinkIdentityRequest _$LinkIdentityRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LinkIdentityRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['nonce']);
      final val = LinkIdentityRequest(
        idToken: $checkedConvert('idToken', (v) => v as String?),
        authorizationCode: $checkedConvert(
          'authorizationCode',
          (v) => v as String?,
        ),
        exchangeCode: $checkedConvert('exchangeCode', (v) => v as String?),
        nonce: $checkedConvert('nonce', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$LinkIdentityRequestToJson(
  LinkIdentityRequest instance,
) => <String, dynamic>{
  'idToken': ?instance.idToken,
  'authorizationCode': ?instance.authorizationCode,
  'exchangeCode': ?instance.exchangeCode,
  'nonce': instance.nonce,
};
