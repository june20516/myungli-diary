// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_preview_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergePreviewRequestCWProxy {
  MergePreviewRequest provider(LoginProvider provider);

  MergePreviewRequest idToken(String? idToken);

  MergePreviewRequest authorizationCode(String? authorizationCode);

  MergePreviewRequest exchangeCode(String? exchangeCode);

  MergePreviewRequest nonce(String nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergePreviewRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergePreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  MergePreviewRequest call({
    LoginProvider provider,
    String? idToken,
    String? authorizationCode,
    String? exchangeCode,
    String nonce,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergePreviewRequest.copyWith(...)` or call `instanceOfMergePreviewRequest.copyWith.fieldName(value)` for a single field.
class _$MergePreviewRequestCWProxyImpl implements _$MergePreviewRequestCWProxy {
  const _$MergePreviewRequestCWProxyImpl(this._value);

  final MergePreviewRequest _value;

  @override
  MergePreviewRequest provider(LoginProvider provider) =>
      call(provider: provider);

  @override
  MergePreviewRequest idToken(String? idToken) => call(idToken: idToken);

  @override
  MergePreviewRequest authorizationCode(String? authorizationCode) =>
      call(authorizationCode: authorizationCode);

  @override
  MergePreviewRequest exchangeCode(String? exchangeCode) =>
      call(exchangeCode: exchangeCode);

  @override
  MergePreviewRequest nonce(String nonce) => call(nonce: nonce);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergePreviewRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergePreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergePreviewRequest call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? idToken = const $CopyWithPlaceholder(),
    Object? authorizationCode = const $CopyWithPlaceholder(),
    Object? exchangeCode = const $CopyWithPlaceholder(),
    Object? nonce = const $CopyWithPlaceholder(),
  }) {
    return MergePreviewRequest(
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as LoginProvider,
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

extension $MergePreviewRequestCopyWith on MergePreviewRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergePreviewRequest.copyWith(...)` or `instanceOfMergePreviewRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergePreviewRequestCWProxy get copyWith =>
      _$MergePreviewRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergePreviewRequest _$MergePreviewRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergePreviewRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['provider', 'nonce']);
      final val = MergePreviewRequest(
        provider: $checkedConvert(
          'provider',
          (v) => $enumDecode(
            _$LoginProviderEnumMap,
            v,
            unknownValue: LoginProvider.unknownDefaultOpenApi,
          ),
        ),
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

Map<String, dynamic> _$MergePreviewRequestToJson(
  MergePreviewRequest instance,
) => <String, dynamic>{
  'provider': _$LoginProviderEnumMap[instance.provider]!,
  'idToken': ?instance.idToken,
  'authorizationCode': ?instance.authorizationCode,
  'exchangeCode': ?instance.exchangeCode,
  'nonce': instance.nonce,
};

const _$LoginProviderEnumMap = {
  LoginProvider.kakao: 'kakao',
  LoginProvider.apple: 'apple',
  LoginProvider.line: 'line',
  LoginProvider.google: 'google',
  LoginProvider.unknownDefaultOpenApi: 'unknown_default_open_api',
};
