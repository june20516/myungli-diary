// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RefreshRequestCWProxy {
  RefreshRequest refreshToken(String refreshToken);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RefreshRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RefreshRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  RefreshRequest call({String refreshToken});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfRefreshRequest.copyWith(...)` or call `instanceOfRefreshRequest.copyWith.fieldName(value)` for a single field.
class _$RefreshRequestCWProxyImpl implements _$RefreshRequestCWProxy {
  const _$RefreshRequestCWProxyImpl(this._value);

  final RefreshRequest _value;

  @override
  RefreshRequest refreshToken(String refreshToken) =>
      call(refreshToken: refreshToken);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RefreshRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RefreshRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  RefreshRequest call({Object? refreshToken = const $CopyWithPlaceholder()}) {
    return RefreshRequest(
      refreshToken:
          refreshToken == const $CopyWithPlaceholder() || refreshToken == null
          ? _value.refreshToken
          // ignore: cast_nullable_to_non_nullable
          : refreshToken as String,
    );
  }
}

extension $RefreshRequestCopyWith on RefreshRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfRefreshRequest.copyWith(...)` or `instanceOfRefreshRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RefreshRequestCWProxy get copyWith => _$RefreshRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RefreshRequest _$RefreshRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RefreshRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['refreshToken']);
      final val = RefreshRequest(
        refreshToken: $checkedConvert('refreshToken', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$RefreshRequestToJson(RefreshRequest instance) =>
    <String, dynamic>{'refreshToken': instance.refreshToken};
