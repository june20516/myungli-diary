// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_profile_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergeProfileSummaryCWProxy {
  MergeProfileSummary status(MergeProfileSummaryStatusEnum status);

  MergeProfileSummary honorific(String? honorific);

  MergeProfileSummary birth(Birth? birth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeProfileSummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeProfileSummary(...).copyWith(id: 12, name: "My name")
  /// ```
  MergeProfileSummary call({
    MergeProfileSummaryStatusEnum status,
    String? honorific,
    Birth? birth,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergeProfileSummary.copyWith(...)` or call `instanceOfMergeProfileSummary.copyWith.fieldName(value)` for a single field.
class _$MergeProfileSummaryCWProxyImpl implements _$MergeProfileSummaryCWProxy {
  const _$MergeProfileSummaryCWProxyImpl(this._value);

  final MergeProfileSummary _value;

  @override
  MergeProfileSummary status(MergeProfileSummaryStatusEnum status) =>
      call(status: status);

  @override
  MergeProfileSummary honorific(String? honorific) =>
      call(honorific: honorific);

  @override
  MergeProfileSummary birth(Birth? birth) => call(birth: birth);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeProfileSummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeProfileSummary(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergeProfileSummary call({
    Object? status = const $CopyWithPlaceholder(),
    Object? honorific = const $CopyWithPlaceholder(),
    Object? birth = const $CopyWithPlaceholder(),
  }) {
    return MergeProfileSummary(
      status: status == const $CopyWithPlaceholder() || status == null
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as MergeProfileSummaryStatusEnum,
      honorific: honorific == const $CopyWithPlaceholder()
          ? _value.honorific
          // ignore: cast_nullable_to_non_nullable
          : honorific as String?,
      birth: birth == const $CopyWithPlaceholder()
          ? _value.birth
          // ignore: cast_nullable_to_non_nullable
          : birth as Birth?,
    );
  }
}

extension $MergeProfileSummaryCopyWith on MergeProfileSummary {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergeProfileSummary.copyWith(...)` or `instanceOfMergeProfileSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergeProfileSummaryCWProxy get copyWith =>
      _$MergeProfileSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergeProfileSummary _$MergeProfileSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergeProfileSummary', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status']);
      final val = MergeProfileSummary(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$MergeProfileSummaryStatusEnumEnumMap, v),
        ),
        honorific: $checkedConvert('honorific', (v) => v as String?),
        birth: $checkedConvert(
          'birth',
          (v) => v == null ? null : Birth.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MergeProfileSummaryToJson(
  MergeProfileSummary instance,
) => <String, dynamic>{
  'status': _$MergeProfileSummaryStatusEnumEnumMap[instance.status]!,
  'honorific': ?instance.honorific,
  'birth': ?instance.birth?.toJson(),
};

const _$MergeProfileSummaryStatusEnumEnumMap = {
  MergeProfileSummaryStatusEnum.saved: 'saved',
  MergeProfileSummaryStatusEnum.none: 'none',
};
