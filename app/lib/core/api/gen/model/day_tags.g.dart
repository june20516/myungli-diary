// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_tags.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DayTagsCWProxy {
  DayTags featured(List<Tag> featured);

  DayTags all(List<String> all);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DayTags(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DayTags(...).copyWith(id: 12, name: "My name")
  /// ```
  DayTags call({List<Tag> featured, List<String> all});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDayTags.copyWith(...)` or call `instanceOfDayTags.copyWith.fieldName(value)` for a single field.
class _$DayTagsCWProxyImpl implements _$DayTagsCWProxy {
  const _$DayTagsCWProxyImpl(this._value);

  final DayTags _value;

  @override
  DayTags featured(List<Tag> featured) => call(featured: featured);

  @override
  DayTags all(List<String> all) => call(all: all);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DayTags(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DayTags(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DayTags call({
    Object? featured = const $CopyWithPlaceholder(),
    Object? all = const $CopyWithPlaceholder(),
  }) {
    return DayTags(
      featured: featured == const $CopyWithPlaceholder() || featured == null
          ? _value.featured
          // ignore: cast_nullable_to_non_nullable
          : featured as List<Tag>,
      all: all == const $CopyWithPlaceholder() || all == null
          ? _value.all
          // ignore: cast_nullable_to_non_nullable
          : all as List<String>,
    );
  }
}

extension $DayTagsCopyWith on DayTags {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDayTags.copyWith(...)` or `instanceOfDayTags.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DayTagsCWProxy get copyWith => _$DayTagsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DayTags _$DayTagsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DayTags', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['featured', 'all']);
      final val = DayTags(
        featured: $checkedConvert(
          'featured',
          (v) => (v as List<dynamic>)
              .map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        all: $checkedConvert(
          'all',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DayTagsToJson(DayTags instance) => <String, dynamic>{
  'featured': instance.featured.map((e) => e.toJson()).toList(),
  'all': instance.all,
};
