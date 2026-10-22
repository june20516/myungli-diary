// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_login_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LineLoginRequestCWProxy {
  LineLoginRequest idToken(String idToken);

  LineLoginRequest nonce(String nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LineLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LineLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  LineLoginRequest call({String idToken, String nonce});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLineLoginRequest.copyWith(...)` or call `instanceOfLineLoginRequest.copyWith.fieldName(value)` for a single field.
class _$LineLoginRequestCWProxyImpl implements _$LineLoginRequestCWProxy {
  const _$LineLoginRequestCWProxyImpl(this._value);

  final LineLoginRequest _value;

  @override
  LineLoginRequest idToken(String idToken) => call(idToken: idToken);

  @override
  LineLoginRequest nonce(String nonce) => call(nonce: nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LineLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LineLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LineLoginRequest call({
    Object? idToken = const $CopyWithPlaceholder(),
    Object? nonce = const $CopyWithPlaceholder(),
  }) {
    return LineLoginRequest(
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

extension $LineLoginRequestCopyWith on LineLoginRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLineLoginRequest.copyWith(...)` or `instanceOfLineLoginRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LineLoginRequestCWProxy get copyWith => _$LineLoginRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LineLoginRequest _$LineLoginRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LineLoginRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['idToken', 'nonce']);
      final val = LineLoginRequest(
        idToken: $checkedConvert('idToken', (v) => v as String),
        nonce: $checkedConvert('nonce', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$LineLoginRequestToJson(LineLoginRequest instance) =>
    <String, dynamic>{'idToken': instance.idToken, 'nonce': instance.nonce};
