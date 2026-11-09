// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_count.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TagCountCWProxy {
  TagCount tag(Tag tag);

  TagCount days(int days);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TagCount(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TagCount(...).copyWith(id: 12, name: "My name")
  /// ```
  TagCount call({Tag tag, int days});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTagCount.copyWith(...)` or call `instanceOfTagCount.copyWith.fieldName(value)` for a single field.
class _$TagCountCWProxyImpl implements _$TagCountCWProxy {
  const _$TagCountCWProxyImpl(this._value);

  final TagCount _value;

  @override
  TagCount tag(Tag tag) => call(tag: tag);

  @override
  TagCount days(int days) => call(days: days);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TagCount(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TagCount(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TagCount call({
    Object? tag = const $CopyWithPlaceholder(),
    Object? days = const $CopyWithPlaceholder(),
  }) {
    return TagCount(
      tag: tag == const $CopyWithPlaceholder() || tag == null
          ? _value.tag
          // ignore: cast_nullable_to_non_nullable
          : tag as Tag,
      days: days == const $CopyWithPlaceholder() || days == null
          ? _value.days
          // ignore: cast_nullable_to_non_nullable
          : days as int,
    );
  }
}

extension $TagCountCopyWith on TagCount {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTagCount.copyWith(...)` or `instanceOfTagCount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TagCountCWProxy get copyWith => _$TagCountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TagCount _$TagCountFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TagCount', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['tag', 'days']);
      final val = TagCount(
        tag: $checkedConvert(
          'tag',
          (v) => Tag.fromJson(v as Map<String, dynamic>),
        ),
        days: $checkedConvert('days', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$TagCountToJson(TagCount instance) => <String, dynamic>{
  'tag': instance.tag.toJson(),
  'days': instance.days,
};
