// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_result.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergeResultCWProxy {
  MergeResult accountId(String accountId);

  MergeResult tokens(TokenPair tokens);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeResult(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeResult(...).copyWith(id: 12, name: "My name")
  /// ```
  MergeResult call({String accountId, TokenPair tokens});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergeResult.copyWith(...)` or call `instanceOfMergeResult.copyWith.fieldName(value)` for a single field.
class _$MergeResultCWProxyImpl implements _$MergeResultCWProxy {
  const _$MergeResultCWProxyImpl(this._value);

  final MergeResult _value;

  @override
  MergeResult accountId(String accountId) => call(accountId: accountId);

  @override
  MergeResult tokens(TokenPair tokens) => call(tokens: tokens);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeResult(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeResult(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergeResult call({
    Object? accountId = const $CopyWithPlaceholder(),
    Object? tokens = const $CopyWithPlaceholder(),
  }) {
    return MergeResult(
      accountId: accountId == const $CopyWithPlaceholder() || accountId == null
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      tokens: tokens == const $CopyWithPlaceholder() || tokens == null
          ? _value.tokens
          // ignore: cast_nullable_to_non_nullable
          : tokens as TokenPair,
    );
  }
}

extension $MergeResultCopyWith on MergeResult {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergeResult.copyWith(...)` or `instanceOfMergeResult.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergeResultCWProxy get copyWith => _$MergeResultCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergeResult _$MergeResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergeResult', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['accountId', 'tokens']);
      final val = MergeResult(
        accountId: $checkedConvert('accountId', (v) => v as String),
        tokens: $checkedConvert(
          'tokens',
          (v) => TokenPair.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MergeResultToJson(MergeResult instance) =>
    <String, dynamic>{
      'accountId': instance.accountId,
      'tokens': instance.tokens.toJson(),
    };
