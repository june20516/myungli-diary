// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiarySummaryCWProxy {
  DiarySummary id(String id);

  DiarySummary date(String date);

  DiarySummary createdAt(DateTime createdAt);

  DiarySummary excerpt(String excerpt);

  DiarySummary featuredTags(List<Tag> featuredTags);

  DiarySummary dayKind(DayKind? dayKind);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiarySummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiarySummary(...).copyWith(id: 12, name: "My name")
  /// ```
  DiarySummary call({
    String id,
    String date,
    DateTime createdAt,
    String excerpt,
    List<Tag> featuredTags,
    DayKind? dayKind,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiarySummary.copyWith(...)` or call `instanceOfDiarySummary.copyWith.fieldName(value)` for a single field.
class _$DiarySummaryCWProxyImpl implements _$DiarySummaryCWProxy {
  const _$DiarySummaryCWProxyImpl(this._value);

  final DiarySummary _value;

  @override
  DiarySummary id(String id) => call(id: id);

  @override
  DiarySummary date(String date) => call(date: date);

  @override
  DiarySummary createdAt(DateTime createdAt) => call(createdAt: createdAt);

  @override
  DiarySummary excerpt(String excerpt) => call(excerpt: excerpt);

  @override
  DiarySummary featuredTags(List<Tag> featuredTags) =>
      call(featuredTags: featuredTags);

  @override
  DiarySummary dayKind(DayKind? dayKind) => call(dayKind: dayKind);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiarySummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiarySummary(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DiarySummary call({
    Object? id = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? excerpt = const $CopyWithPlaceholder(),
    Object? featuredTags = const $CopyWithPlaceholder(),
    Object? dayKind = const $CopyWithPlaceholder(),
  }) {
    return DiarySummary(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String,
      createdAt: createdAt == const $CopyWithPlaceholder() || createdAt == null
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      excerpt: excerpt == const $CopyWithPlaceholder() || excerpt == null
          ? _value.excerpt
          // ignore: cast_nullable_to_non_nullable
          : excerpt as String,
      featuredTags:
          featuredTags == const $CopyWithPlaceholder() || featuredTags == null
          ? _value.featuredTags
          // ignore: cast_nullable_to_non_nullable
          : featuredTags as List<Tag>,
      dayKind: dayKind == const $CopyWithPlaceholder()
          ? _value.dayKind
          // ignore: cast_nullable_to_non_nullable
          : dayKind as DayKind?,
    );
  }
}

extension $DiarySummaryCopyWith on DiarySummary {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDiarySummary.copyWith(...)` or `instanceOfDiarySummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiarySummaryCWProxy get copyWith => _$DiarySummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiarySummary _$DiarySummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DiarySummary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['id', 'date', 'createdAt', 'excerpt', 'featuredTags'],
  );
  final val = DiarySummary(
    id: $checkedConvert('id', (v) => v as String),
    date: $checkedConvert('date', (v) => v as String),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    excerpt: $checkedConvert('excerpt', (v) => v as String),
    featuredTags: $checkedConvert(
      'featuredTags',
      (v) => (v as List<dynamic>)
          .map((e) => Tag.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    dayKind: $checkedConvert(
      'dayKind',
      (v) => $enumDecodeNullable(_$DayKindEnumMap, v),
    ),
  );
  return val;
});

Map<String, dynamic> _$DiarySummaryToJson(DiarySummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date,
      'createdAt': instance.createdAt.toIso8601String(),
      'excerpt': instance.excerpt,
      'featuredTags': instance.featuredTags.map((e) => e.toJson()).toList(),
      'dayKind': ?_$DayKindEnumMap[instance.dayKind],
    };

const _$DayKindEnumMap = {
  DayKind.gwiinDay: 'gwiin_day',
  DayKind.yongsinDay: 'yongsin_day',
  DayKind.gisinDay: 'gisin_day',
  DayKind.ordinaryDay: 'ordinary_day',
};
