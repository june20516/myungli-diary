// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merge_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MergeSummaryCWProxy {
  MergeSummary diaries(int diaries);

  MergeSummary schedules(int schedules);

  MergeSummary dateRecords(int dateRecords);

  MergeSummary reactions(int reactions);

  MergeSummary overlapDays(int overlapDays);

  MergeSummary addedDays(MergeAddedDays addedDays);

  MergeSummary current(MergeProfileSummary current);

  MergeSummary other(MergeProfileSummary other);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeSummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeSummary(...).copyWith(id: 12, name: "My name")
  /// ```
  MergeSummary call({
    int diaries,
    int schedules,
    int dateRecords,
    int reactions,
    int overlapDays,
    MergeAddedDays addedDays,
    MergeProfileSummary current,
    MergeProfileSummary other,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMergeSummary.copyWith(...)` or call `instanceOfMergeSummary.copyWith.fieldName(value)` for a single field.
class _$MergeSummaryCWProxyImpl implements _$MergeSummaryCWProxy {
  const _$MergeSummaryCWProxyImpl(this._value);

  final MergeSummary _value;

  @override
  MergeSummary diaries(int diaries) => call(diaries: diaries);

  @override
  MergeSummary schedules(int schedules) => call(schedules: schedules);

  @override
  MergeSummary dateRecords(int dateRecords) => call(dateRecords: dateRecords);

  @override
  MergeSummary reactions(int reactions) => call(reactions: reactions);

  @override
  MergeSummary overlapDays(int overlapDays) => call(overlapDays: overlapDays);

  @override
  MergeSummary addedDays(MergeAddedDays addedDays) =>
      call(addedDays: addedDays);

  @override
  MergeSummary current(MergeProfileSummary current) => call(current: current);

  @override
  MergeSummary other(MergeProfileSummary other) => call(other: other);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MergeSummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MergeSummary(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MergeSummary call({
    Object? diaries = const $CopyWithPlaceholder(),
    Object? schedules = const $CopyWithPlaceholder(),
    Object? dateRecords = const $CopyWithPlaceholder(),
    Object? reactions = const $CopyWithPlaceholder(),
    Object? overlapDays = const $CopyWithPlaceholder(),
    Object? addedDays = const $CopyWithPlaceholder(),
    Object? current = const $CopyWithPlaceholder(),
    Object? other = const $CopyWithPlaceholder(),
  }) {
    return MergeSummary(
      diaries: diaries == const $CopyWithPlaceholder() || diaries == null
          ? _value.diaries
          // ignore: cast_nullable_to_non_nullable
          : diaries as int,
      schedules: schedules == const $CopyWithPlaceholder() || schedules == null
          ? _value.schedules
          // ignore: cast_nullable_to_non_nullable
          : schedules as int,
      dateRecords:
          dateRecords == const $CopyWithPlaceholder() || dateRecords == null
          ? _value.dateRecords
          // ignore: cast_nullable_to_non_nullable
          : dateRecords as int,
      reactions: reactions == const $CopyWithPlaceholder() || reactions == null
          ? _value.reactions
          // ignore: cast_nullable_to_non_nullable
          : reactions as int,
      overlapDays:
          overlapDays == const $CopyWithPlaceholder() || overlapDays == null
          ? _value.overlapDays
          // ignore: cast_nullable_to_non_nullable
          : overlapDays as int,
      addedDays: addedDays == const $CopyWithPlaceholder() || addedDays == null
          ? _value.addedDays
          // ignore: cast_nullable_to_non_nullable
          : addedDays as MergeAddedDays,
      current: current == const $CopyWithPlaceholder() || current == null
          ? _value.current
          // ignore: cast_nullable_to_non_nullable
          : current as MergeProfileSummary,
      other: other == const $CopyWithPlaceholder() || other == null
          ? _value.other
          // ignore: cast_nullable_to_non_nullable
          : other as MergeProfileSummary,
    );
  }
}

extension $MergeSummaryCopyWith on MergeSummary {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMergeSummary.copyWith(...)` or `instanceOfMergeSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MergeSummaryCWProxy get copyWith => _$MergeSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MergeSummary _$MergeSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MergeSummary', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'diaries',
          'schedules',
          'dateRecords',
          'reactions',
          'overlapDays',
          'addedDays',
          'current',
          'other',
        ],
      );
      final val = MergeSummary(
        diaries: $checkedConvert('diaries', (v) => (v as num).toInt()),
        schedules: $checkedConvert('schedules', (v) => (v as num).toInt()),
        dateRecords: $checkedConvert('dateRecords', (v) => (v as num).toInt()),
        reactions: $checkedConvert('reactions', (v) => (v as num).toInt()),
        overlapDays: $checkedConvert('overlapDays', (v) => (v as num).toInt()),
        addedDays: $checkedConvert(
          'addedDays',
          (v) => MergeAddedDays.fromJson(v as Map<String, dynamic>),
        ),
        current: $checkedConvert(
          'current',
          (v) => MergeProfileSummary.fromJson(v as Map<String, dynamic>),
        ),
        other: $checkedConvert(
          'other',
          (v) => MergeProfileSummary.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MergeSummaryToJson(MergeSummary instance) =>
    <String, dynamic>{
      'diaries': instance.diaries,
      'schedules': instance.schedules,
      'dateRecords': instance.dateRecords,
      'reactions': instance.reactions,
      'overlapDays': instance.overlapDays,
      'addedDays': instance.addedDays.toJson(),
      'current': instance.current.toJson(),
      'other': instance.other.toJson(),
    };
