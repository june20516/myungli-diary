// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergePreviewCWProxy {
  MergePreview current(MergeAccountSummary current);

  MergePreview other(MergeAccountSummary other);

  MergePreview overlapDayCount(int overlapDayCount);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergePreview(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergePreview(...).copyWith(id: 12, name: "My name")
  /// ```
  MergePreview call({
    MergeAccountSummary current,
    MergeAccountSummary other,
    int overlapDayCount,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergePreview.copyWith(...)` or call `instanceOfMergePreview.copyWith.fieldName(value)` for a single field.
class _$MergePreviewCWProxyImpl implements _$MergePreviewCWProxy {
  const _$MergePreviewCWProxyImpl(this._value);

  final MergePreview _value;

  @override
  MergePreview current(MergeAccountSummary current) => call(current: current);

  @override
  MergePreview other(MergeAccountSummary other) => call(other: other);

  @override
  MergePreview overlapDayCount(int overlapDayCount) =>
      call(overlapDayCount: overlapDayCount);

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
    Object? current = const $CopyWithPlaceholder(),
    Object? other = const $CopyWithPlaceholder(),
    Object? overlapDayCount = const $CopyWithPlaceholder(),
  }) {
    return MergePreview(
      current: current == const $CopyWithPlaceholder() || current == null
          ? _value.current
          // ignore: cast_nullable_to_non_nullable
          : current as MergeAccountSummary,
      other: other == const $CopyWithPlaceholder() || other == null
          ? _value.other
          // ignore: cast_nullable_to_non_nullable
          : other as MergeAccountSummary,
      overlapDayCount:
          overlapDayCount == const $CopyWithPlaceholder() ||
              overlapDayCount == null
          ? _value.overlapDayCount
          // ignore: cast_nullable_to_non_nullable
          : overlapDayCount as int,
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

MergePreview _$MergePreviewFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergePreview', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['current', 'other', 'overlapDayCount'],
      );
      final val = MergePreview(
        current: $checkedConvert(
          'current',
          (v) => MergeAccountSummary.fromJson(v as Map<String, dynamic>),
        ),
        other: $checkedConvert(
          'other',
          (v) => MergeAccountSummary.fromJson(v as Map<String, dynamic>),
        ),
        overlapDayCount: $checkedConvert(
          'overlapDayCount',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MergePreviewToJson(MergePreview instance) =>
    <String, dynamic>{
      'current': instance.current.toJson(),
      'other': instance.other.toJson(),
      'overlapDayCount': instance.overlapDayCount,
    };
