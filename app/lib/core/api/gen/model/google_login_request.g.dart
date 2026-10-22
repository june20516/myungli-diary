// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_login_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GoogleLoginRequestCWProxy {
  GoogleLoginRequest idToken(String idToken);

  GoogleLoginRequest nonce(String nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GoogleLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GoogleLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  GoogleLoginRequest call({String idToken, String nonce});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGoogleLoginRequest.copyWith(...)` or call `instanceOfGoogleLoginRequest.copyWith.fieldName(value)` for a single field.
class _$GoogleLoginRequestCWProxyImpl implements _$GoogleLoginRequestCWProxy {
  const _$GoogleLoginRequestCWProxyImpl(this._value);

  final GoogleLoginRequest _value;

  @override
  GoogleLoginRequest idToken(String idToken) => call(idToken: idToken);

  @override
  GoogleLoginRequest nonce(String nonce) => call(nonce: nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GoogleLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GoogleLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GoogleLoginRequest call({
    Object? idToken = const $CopyWithPlaceholder(),
    Object? nonce = const $CopyWithPlaceholder(),
  }) {
    return GoogleLoginRequest(
      idToken: idToken == const $CopyWithPlaceholder() || idToken == null
          ? _value.idToken
          // ignore: cast_nullable_to_non_nullable
          : idToken as String,
      nonce: nonce == const $CopyWithPlaceholder() || nonce == null
          ? _value.nonce
          // ignore: cast_nullable_to_non_nullable
          : nonce as String,
    );
  }
}

extension $GoogleLoginRequestCopyWith on GoogleLoginRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGoogleLoginRequest.copyWith(...)` or `instanceOfGoogleLoginRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GoogleLoginRequestCWProxy get copyWith =>
      _$GoogleLoginRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleLoginRequest _$GoogleLoginRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GoogleLoginRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['idToken', 'nonce']);
      final val = GoogleLoginRequest(
        idToken: $checkedConvert('idToken', (v) => v as String),
        nonce: $checkedConvert('nonce', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$GoogleLoginRequestToJson(GoogleLoginRequest instance) =>
    <String, dynamic>{'idToken': instance.idToken, 'nonce': instance.nonce};
