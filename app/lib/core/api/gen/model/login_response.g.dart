// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LoginResponseCWProxy {
  LoginResponse tokens(TokenPair tokens);

  LoginResponse isNewAccount(bool isNewAccount);

  LoginResponse consentRequired(bool consentRequired);

  LoginResponse restoredFromDeletion(bool restoredFromDeletion);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LoginResponse(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LoginResponse(...).copyWith(id: 12, name: "My name")
  /// ```
  LoginResponse call({
    TokenPair tokens,
    bool isNewAccount,
    bool consentRequired,
    bool restoredFromDeletion,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLoginResponse.copyWith(...)` or call `instanceOfLoginResponse.copyWith.fieldName(value)` for a single field.
class _$LoginResponseCWProxyImpl implements _$LoginResponseCWProxy {
  const _$LoginResponseCWProxyImpl(this._value);

  final LoginResponse _value;

  @override
  LoginResponse tokens(TokenPair tokens) => call(tokens: tokens);

  @override
  LoginResponse isNewAccount(bool isNewAccount) =>
      call(isNewAccount: isNewAccount);

  @override
  LoginResponse consentRequired(bool consentRequired) =>
      call(consentRequired: consentRequired);

  @override
  LoginResponse restoredFromDeletion(bool restoredFromDeletion) =>
      call(restoredFromDeletion: restoredFromDeletion);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LoginResponse(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LoginResponse(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LoginResponse call({
    Object? tokens = const $CopyWithPlaceholder(),
    Object? isNewAccount = const $CopyWithPlaceholder(),
    Object? consentRequired = const $CopyWithPlaceholder(),
    Object? restoredFromDeletion = const $CopyWithPlaceholder(),
  }) {
    return LoginResponse(
      tokens: tokens == const $CopyWithPlaceholder() || tokens == null
          ? _value.tokens
          // ignore: cast_nullable_to_non_nullable
          : tokens as TokenPair,
      isNewAccount:
          isNewAccount == const $CopyWithPlaceholder() || isNewAccount == null
          ? _value.isNewAccount
          // ignore: cast_nullable_to_non_nullable
          : isNewAccount as bool,
      consentRequired:
          consentRequired == const $CopyWithPlaceholder() ||
              consentRequired == null
          ? _value.consentRequired
          // ignore: cast_nullable_to_non_nullable
          : consentRequired as bool,
      restoredFromDeletion:
          restoredFromDeletion == const $CopyWithPlaceholder() ||
              restoredFromDeletion == null
          ? _value.restoredFromDeletion
          // ignore: cast_nullable_to_non_nullable
          : restoredFromDeletion as bool,
    );
  }
}

extension $LoginResponseCopyWith on LoginResponse {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLoginResponse.copyWith(...)` or `instanceOfLoginResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LoginResponseCWProxy get copyWith => _$LoginResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LoginResponse', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'tokens',
          'isNewAccount',
          'consentRequired',
          'restoredFromDeletion',
        ],
      );
      final val = LoginResponse(
        tokens: $checkedConvert(
          'tokens',
          (v) => TokenPair.fromJson(v as Map<String, dynamic>),
        ),
        isNewAccount: $checkedConvert('isNewAccount', (v) => v as bool),
        consentRequired: $checkedConvert('consentRequired', (v) => v as bool),
        restoredFromDeletion: $checkedConvert(
          'restoredFromDeletion',
          (v) => v as bool,
        ),
      );
      return val;
    });

Map<String, dynamic> _$LoginResponseToJson(LoginResponse instance) =>
    <String, dynamic>{
      'tokens': instance.tokens.toJson(),
      'isNewAccount': instance.isNewAccount,
      'consentRequired': instance.consentRequired,
      'restoredFromDeletion': instance.restoredFromDeletion,
    };
