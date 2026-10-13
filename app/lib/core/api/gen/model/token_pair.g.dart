// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_pair.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TokenPairCWProxy {
  TokenPair accessToken(String accessToken);

  TokenPair accessTokenExpiresAt(DateTime accessTokenExpiresAt);

  TokenPair refreshToken(String refreshToken);

  TokenPair refreshTokenExpiresAt(DateTime refreshTokenExpiresAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TokenPair(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TokenPair(...).copyWith(id: 12, name: "My name")
  /// ```
  TokenPair call({
    String accessToken,
    DateTime accessTokenExpiresAt,
    String refreshToken,
    DateTime refreshTokenExpiresAt,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTokenPair.copyWith(...)` or call `instanceOfTokenPair.copyWith.fieldName(value)` for a single field.
class _$TokenPairCWProxyImpl implements _$TokenPairCWProxy {
  const _$TokenPairCWProxyImpl(this._value);

  final TokenPair _value;

  @override
  TokenPair accessToken(String accessToken) => call(accessToken: accessToken);

  @override
  TokenPair accessTokenExpiresAt(DateTime accessTokenExpiresAt) =>
      call(accessTokenExpiresAt: accessTokenExpiresAt);

  @override
  TokenPair refreshToken(String refreshToken) =>
      call(refreshToken: refreshToken);

  @override
  TokenPair refreshTokenExpiresAt(DateTime refreshTokenExpiresAt) =>
      call(refreshTokenExpiresAt: refreshTokenExpiresAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TokenPair(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TokenPair(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TokenPair call({
    Object? accessToken = const $CopyWithPlaceholder(),
    Object? accessTokenExpiresAt = const $CopyWithPlaceholder(),
    Object? refreshToken = const $CopyWithPlaceholder(),
    Object? refreshTokenExpiresAt = const $CopyWithPlaceholder(),
  }) {
    return TokenPair(
      accessToken:
          accessToken == const $CopyWithPlaceholder() || accessToken == null
          ? _value.accessToken
          // ignore: cast_nullable_to_non_nullable
          : accessToken as String,
      accessTokenExpiresAt:
          accessTokenExpiresAt == const $CopyWithPlaceholder() ||
              accessTokenExpiresAt == null
          ? _value.accessTokenExpiresAt
          // ignore: cast_nullable_to_non_nullable
          : accessTokenExpiresAt as DateTime,
      refreshToken:
          refreshToken == const $CopyWithPlaceholder() || refreshToken == null
          ? _value.refreshToken
          // ignore: cast_nullable_to_non_nullable
          : refreshToken as String,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt == const $CopyWithPlaceholder() ||
              refreshTokenExpiresAt == null
          ? _value.refreshTokenExpiresAt
          // ignore: cast_nullable_to_non_nullable
          : refreshTokenExpiresAt as DateTime,
    );
  }
}

extension $TokenPairCopyWith on TokenPair {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTokenPair.copyWith(...)` or `instanceOfTokenPair.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TokenPairCWProxy get copyWith => _$TokenPairCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenPair _$TokenPairFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TokenPair', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'accessToken',
          'accessTokenExpiresAt',
          'refreshToken',
          'refreshTokenExpiresAt',
        ],
      );
      final val = TokenPair(
        accessToken: $checkedConvert('accessToken', (v) => v as String),
        accessTokenExpiresAt: $checkedConvert(
          'accessTokenExpiresAt',
          (v) => DateTime.parse(v as String),
        ),
        refreshToken: $checkedConvert('refreshToken', (v) => v as String),
        refreshTokenExpiresAt: $checkedConvert(
          'refreshTokenExpiresAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TokenPairToJson(TokenPair instance) => <String, dynamic>{
  'accessToken': instance.accessToken,
  'accessTokenExpiresAt': instance.accessTokenExpiresAt.toIso8601String(),
  'refreshToken': instance.refreshToken,
  'refreshTokenExpiresAt': instance.refreshTokenExpiresAt.toIso8601String(),
};
