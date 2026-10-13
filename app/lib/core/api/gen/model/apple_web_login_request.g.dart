// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_web_login_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AppleWebLoginRequestCWProxy {
  AppleWebLoginRequest exchangeCode(String exchangeCode);

  AppleWebLoginRequest nonce(String nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AppleWebLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AppleWebLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  AppleWebLoginRequest call({String exchangeCode, String nonce});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAppleWebLoginRequest.copyWith(...)` or call `instanceOfAppleWebLoginRequest.copyWith.fieldName(value)` for a single field.
class _$AppleWebLoginRequestCWProxyImpl
    implements _$AppleWebLoginRequestCWProxy {
  const _$AppleWebLoginRequestCWProxyImpl(this._value);

  final AppleWebLoginRequest _value;

  @override
  AppleWebLoginRequest exchangeCode(String exchangeCode) =>
      call(exchangeCode: exchangeCode);

  @override
  AppleWebLoginRequest nonce(String nonce) => call(nonce: nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AppleWebLoginRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AppleWebLoginRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  AppleWebLoginRequest call({
    Object? exchangeCode = const $CopyWithPlaceholder(),
    Object? nonce = const $CopyWithPlaceholder(),
  }) {
    return AppleWebLoginRequest(
      exchangeCode:
          exchangeCode == const $CopyWithPlaceholder() || exchangeCode == null
          ? _value.exchangeCode
          // ignore: cast_nullable_to_non_nullable
          : exchangeCode as String,
      nonce: nonce == const $CopyWithPlaceholder() || nonce == null
          ? _value.nonce
          // ignore: cast_nullable_to_non_nullable
          : nonce as String,
    );
  }
}

extension $AppleWebLoginRequestCopyWith on AppleWebLoginRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAppleWebLoginRequest.copyWith(...)` or `instanceOfAppleWebLoginRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AppleWebLoginRequestCWProxy get copyWith =>
      _$AppleWebLoginRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppleWebLoginRequest _$AppleWebLoginRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AppleWebLoginRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['exchangeCode', 'nonce']);
  final val = AppleWebLoginRequest(
    exchangeCode: $checkedConvert('exchangeCode', (v) => v as String),
    nonce: $checkedConvert('nonce', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$AppleWebLoginRequestToJson(
  AppleWebLoginRequest instance,
) => <String, dynamic>{
  'exchangeCode': instance.exchangeCode,
  'nonce': instance.nonce,
};
