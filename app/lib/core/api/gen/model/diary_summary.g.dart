// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiarySummaryCWProxy {
  DiarySummary date(String date);

  DiarySummary excerpt(String excerpt);

  DiarySummary featuredTags(List<Tag> featuredTags);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiarySummary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiarySummary(...).copyWith(id: 12, name: "My name")
  /// ```
  DiarySummary call({String date, String excerpt, List<Tag> featuredTags});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiarySummary.copyWith(...)` or call `instanceOfDiarySummary.copyWith.fieldName(value)` for a single field.
class _$DiarySummaryCWProxyImpl implements _$DiarySummaryCWProxy {
  const _$DiarySummaryCWProxyImpl(this._value);

  final DiarySummary _value;

  @override
  DiarySummary date(String date) => call(date: date);

  @override
  DiarySummary excerpt(String excerpt) => call(excerpt: excerpt);

  @override
  DiarySummary featuredTags(List<Tag> featuredTags) =>
      call(featuredTags: featuredTags);

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
    Object? date = const $CopyWithPlaceholder(),
    Object? excerpt = const $CopyWithPlaceholder(),
    Object? featuredTags = const $CopyWithPlaceholder(),
  }) {
    return DiarySummary(
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String,
      excerpt: excerpt == const $CopyWithPlaceholder() || excerpt == null
          ? _value.excerpt
          // ignore: cast_nullable_to_non_nullable
          : excerpt as String,
      featuredTags:
          featuredTags == const $CopyWithPlaceholder() || featuredTags == null
          ? _value.featuredTags
          // ignore: cast_nullable_to_non_nullable
          : featuredTags as List<Tag>,
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

DiarySummary _$DiarySummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiarySummary', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['date', 'excerpt', 'featuredTags']);
      final val = DiarySummary(
        date: $checkedConvert('date', (v) => v as String),
        excerpt: $checkedConvert('excerpt', (v) => v as String),
        featuredTags: $checkedConvert(
          'featuredTags',
          (v) => (v as List<dynamic>)
              .map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DiarySummaryToJson(DiarySummary instance) =>
    <String, dynamic>{
      'date': instance.date,
      'excerpt': instance.excerpt,
      'featuredTags': instance.featuredTags.map((e) => e.toJson()).toList(),
    };
