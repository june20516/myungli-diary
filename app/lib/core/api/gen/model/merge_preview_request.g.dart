// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_preview_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergePreviewRequestCWProxy {
  MergePreviewRequest mergeToken(String mergeToken);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergePreviewRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergePreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  MergePreviewRequest call({String mergeToken});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergePreviewRequest.copyWith(...)` or call `instanceOfMergePreviewRequest.copyWith.fieldName(value)` for a single field.
class _$MergePreviewRequestCWProxyImpl implements _$MergePreviewRequestCWProxy {
  const _$MergePreviewRequestCWProxyImpl(this._value);

  final MergePreviewRequest _value;

  @override
  MergePreviewRequest mergeToken(String mergeToken) =>
      call(mergeToken: mergeToken);

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
    Object? mergeToken = const $CopyWithPlaceholder(),
  }) {
    return MergePreviewRequest(
      mergeToken:
          mergeToken == const $CopyWithPlaceholder() || mergeToken == null
          ? _value.mergeToken
          // ignore: cast_nullable_to_non_nullable
          : mergeToken as String,
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
      $checkKeys(json, requiredKeys: const ['mergeToken']);
      final val = MergePreviewRequest(
        mergeToken: $checkedConvert('mergeToken', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$MergePreviewRequestToJson(
  MergePreviewRequest instance,
) => <String, dynamic>{'mergeToken': instance.mergeToken};
