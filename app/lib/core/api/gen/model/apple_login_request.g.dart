// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_login_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AppleLoginRequestCWProxy {
  AppleLoginRequest idToken(String idToken);

  AppleLoginRequest authorizationCode(String authorizationCode);

  AppleLoginRequest nonce(String nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AppleLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AppleLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  AppleLoginRequest call({
    String idToken,
    String authorizationCode,
    String nonce,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAppleLoginRequest.copyWith(...)` or call `instanceOfAppleLoginRequest.copyWith.fieldName(value)` for a single field.
class _$AppleLoginRequestCWProxyImpl implements _$AppleLoginRequestCWProxy {
  const _$AppleLoginRequestCWProxyImpl(this._value);

  final AppleLoginRequest _value;

  @override
  AppleLoginRequest idToken(String idToken) => call(idToken: idToken);

  @override
  AppleLoginRequest authorizationCode(String authorizationCode) =>
      call(authorizationCode: authorizationCode);

  @override
  AppleLoginRequest nonce(String nonce) => call(nonce: nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AppleLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AppleLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  AppleLoginRequest call({
    Object? idToken = const $CopyWithPlaceholder(),
    Object? authorizationCode = const $CopyWithPlaceholder(),
    Object? nonce = const $CopyWithPlaceholder(),
  }) {
    return AppleLoginRequest(
      idToken: idToken == const $CopyWithPlaceholder() || idToken == null
          ? _value.idToken
          // ignore: cast_nullable_to_non_nullable
          : idToken as String,
      authorizationCode:
          authorizationCode == const $CopyWithPlaceholder() ||
              authorizationCode == null
          ? _value.authorizationCode
          // ignore: cast_nullable_to_non_nullable
          : authorizationCode as String,
      nonce: nonce == const $CopyWithPlaceholder() || nonce == null
          ? _value.nonce
          // ignore: cast_nullable_to_non_nullable
          : nonce as String,
    );
  }
}

extension $AppleLoginRequestCopyWith on AppleLoginRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAppleLoginRequest.copyWith(...)` or `instanceOfAppleLoginRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AppleLoginRequestCWProxy get copyWith =>
      _$AppleLoginRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppleLoginRequest _$AppleLoginRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AppleLoginRequest', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['idToken', 'authorizationCode', 'nonce'],
      );
      final val = AppleLoginRequest(
        idToken: $checkedConvert('idToken', (v) => v as String),
        authorizationCode: $checkedConvert(
          'authorizationCode',
          (v) => v as String,
        ),
        nonce: $checkedConvert('nonce', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$AppleLoginRequestToJson(AppleLoginRequest instance) =>
    <String, dynamic>{
      'idToken': instance.idToken,
      'authorizationCode': instance.authorizationCode,
      'nonce': instance.nonce,
    };
