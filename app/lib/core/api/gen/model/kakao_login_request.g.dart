// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kakao_login_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$KakaoLoginRequestCWProxy {
  KakaoLoginRequest idToken(String idToken);

  KakaoLoginRequest nonce(String nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `KakaoLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// KakaoLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  KakaoLoginRequest call({String idToken, String nonce});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfKakaoLoginRequest.copyWith(...)` or call `instanceOfKakaoLoginRequest.copyWith.fieldName(value)` for a single field.
class _$KakaoLoginRequestCWProxyImpl implements _$KakaoLoginRequestCWProxy {
  const _$KakaoLoginRequestCWProxyImpl(this._value);

  final KakaoLoginRequest _value;

  @override
  KakaoLoginRequest idToken(String idToken) => call(idToken: idToken);

  @override
  KakaoLoginRequest nonce(String nonce) => call(nonce: nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `KakaoLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// KakaoLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  KakaoLoginRequest call({
    Object? idToken = const $CopyWithPlaceholder(),
    Object? nonce = const $CopyWithPlaceholder(),
  }) {
    return KakaoLoginRequest(
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

extension $KakaoLoginRequestCopyWith on KakaoLoginRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfKakaoLoginRequest.copyWith(...)` or `instanceOfKakaoLoginRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$KakaoLoginRequestCWProxy get copyWith =>
      _$KakaoLoginRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KakaoLoginRequest _$KakaoLoginRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('KakaoLoginRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['idToken', 'nonce']);
      final val = KakaoLoginRequest(
        idToken: $checkedConvert('idToken', (v) => v as String),
        nonce: $checkedConvert('nonce', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$KakaoLoginRequestToJson(KakaoLoginRequest instance) =>
    <String, dynamic>{'idToken': instance.idToken, 'nonce': instance.nonce};
