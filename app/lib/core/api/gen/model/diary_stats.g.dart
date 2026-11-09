// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_stats.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiaryStatsCWProxy {
  DiaryStats entryCount(int entryCount);

  DiaryStats dayKinds(List<DayKindCount> dayKinds);

  DiaryStats topTags(List<TagCount> topTags);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryStats(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryStats(...).copyWith(id: 12, name: "My name")
  /// ```
  DiaryStats call({
    int entryCount,
    List<DayKindCount> dayKinds,
    List<TagCount> topTags,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiaryStats.copyWith(...)` or call `instanceOfDiaryStats.copyWith.fieldName(value)` for a single field.
class _$DiaryStatsCWProxyImpl implements _$DiaryStatsCWProxy {
  const _$DiaryStatsCWProxyImpl(this._value);

  final DiaryStats _value;

  @override
  DiaryStats entryCount(int entryCount) => call(entryCount: entryCount);

  @override
  DiaryStats dayKinds(List<DayKindCount> dayKinds) => call(dayKinds: dayKinds);

  @override
  DiaryStats topTags(List<TagCount> topTags) => call(topTags: topTags);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryStats(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryStats(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DiaryStats call({
    Object? entryCount = const $CopyWithPlaceholder(),
    Object? dayKinds = const $CopyWithPlaceholder(),
    Object? topTags = const $CopyWithPlaceholder(),
  }) {
    return DiaryStats(
      entryCount:
          entryCount == const $CopyWithPlaceholder() || entryCount == null
          ? _value.entryCount
          // ignore: cast_nullable_to_non_nullable
          : entryCount as int,
      dayKinds: dayKinds == const $CopyWithPlaceholder() || dayKinds == null
          ? _value.dayKinds
          // ignore: cast_nullable_to_non_nullable
          : dayKinds as List<DayKindCount>,
      topTags: topTags == const $CopyWithPlaceholder() || topTags == null
          ? _value.topTags
          // ignore: cast_nullable_to_non_nullable
          : topTags as List<TagCount>,
    );
  }
}

extension $DiaryStatsCopyWith on DiaryStats {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDiaryStats.copyWith(...)` or `instanceOfDiaryStats.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiaryStatsCWProxy get copyWith => _$DiaryStatsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiaryStats _$DiaryStatsFromJson(Map<String, dynamic> json) => $checkedCreate(
  'DiaryStats',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['entryCount', 'dayKinds', 'topTags']);
    final val = DiaryStats(
      entryCount: $checkedConvert('entryCount', (v) => (v as num).toInt()),
      dayKinds: $checkedConvert(
        'dayKinds',
        (v) => (v as List<dynamic>)
            .map((e) => DayKindCount.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      topTags: $checkedConvert(
        'topTags',
        (v) => (v as List<dynamic>)
            .map((e) => TagCount.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
);

Map<String, dynamic> _$DiaryStatsToJson(DiaryStats instance) =>
    <String, dynamic>{
      'entryCount': instance.entryCount,
      'dayKinds': instance.dayKinds.map((e) => e.toJson()).toList(),
      'topTags': instance.topTags.map((e) => e.toJson()).toList(),
    };
