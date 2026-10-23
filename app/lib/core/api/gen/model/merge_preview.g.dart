// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergePreviewCWProxy {
  MergePreview mergeToken(String mergeToken);

  MergePreview expiresAt(DateTime expiresAt);

  MergePreview summary(MergeSummary summary);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergePreview(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergePreview(...).copyWith(id: 12, name: "My name")
  /// ```
  MergePreview call({
    String mergeToken,
    DateTime expiresAt,
    MergeSummary summary,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergePreview.copyWith(...)` or call `instanceOfMergePreview.copyWith.fieldName(value)` for a single field.
class _$MergePreviewCWProxyImpl implements _$MergePreviewCWProxy {
  const _$MergePreviewCWProxyImpl(this._value);

  final MergePreview _value;

  @override
  MergePreview mergeToken(String mergeToken) => call(mergeToken: mergeToken);

  @override
  MergePreview expiresAt(DateTime expiresAt) => call(expiresAt: expiresAt);

  @override
  MergePreview summary(MergeSummary summary) => call(summary: summary);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergePreview(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergePreview(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergePreview call({
    Object? mergeToken = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
  }) {
    return MergePreview(
      mergeToken:
          mergeToken == const $CopyWithPlaceholder() || mergeToken == null
          ? _value.mergeToken
          // ignore: cast_nullable_to_non_nullable
          : mergeToken as String,
      expiresAt: expiresAt == const $CopyWithPlaceholder() || expiresAt == null
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      summary: summary == const $CopyWithPlaceholder() || summary == null
          ? _value.summary
          // ignore: cast_nullable_to_non_nullable
          : summary as MergeSummary,
    );
  }
}

extension $MergePreviewCopyWith on MergePreview {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergePreview.copyWith(...)` or `instanceOfMergePreview.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergePreviewCWProxy get copyWith => _$MergePreviewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergePreview _$MergePreviewFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MergePreview', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['mergeToken', 'expiresAt', 'summary']);
  final val = MergePreview(
    mergeToken: $checkedConvert('mergeToken', (v) => v as String),
    expiresAt: $checkedConvert('expiresAt', (v) => DateTime.parse(v as String)),
    summary: $checkedConvert(
      'summary',
      (v) => MergeSummary.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$MergePreviewToJson(MergePreview instance) =>
    <String, dynamic>{
      'mergeToken': instance.mergeToken,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'summary': instance.summary.toJson(),
    };
