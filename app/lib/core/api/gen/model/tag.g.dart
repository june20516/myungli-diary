// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TagCWProxy {
  Tag key(String key);

  Tag polarity(TagPolarityEnum polarity);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Tag(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Tag(...).copyWith(id: 12, name: "My name")
  /// ```
  Tag call({String key, TagPolarityEnum polarity});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTag.copyWith(...)` or call `instanceOfTag.copyWith.fieldName(value)` for a single field.
class _$TagCWProxyImpl implements _$TagCWProxy {
  const _$TagCWProxyImpl(this._value);

  final Tag _value;

  @override
  Tag key(String key) => call(key: key);

  @override
  Tag polarity(TagPolarityEnum polarity) => call(polarity: polarity);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Tag(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Tag(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Tag call({
    Object? key = const $CopyWithPlaceholder(),
    Object? polarity = const $CopyWithPlaceholder(),
  }) {
    return Tag(
      key: key == const $CopyWithPlaceholder() || key == null
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as String,
      polarity: polarity == const $CopyWithPlaceholder() || polarity == null
          ? _value.polarity
          // ignore: cast_nullable_to_non_nullable
          : polarity as TagPolarityEnum,
    );
  }
}

extension $TagCopyWith on Tag {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTag.copyWith(...)` or `instanceOfTag.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TagCWProxy get copyWith => _$TagCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tag _$TagFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Tag', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key', 'polarity']);
      final val = Tag(
        key: $checkedConvert('key', (v) => v as String),
        polarity: $checkedConvert(
          'polarity',
          (v) => $enumDecode(_$TagPolarityEnumEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TagToJson(Tag instance) => <String, dynamic>{
  'key': instance.key,
  'polarity': _$TagPolarityEnumEnumMap[instance.polarity]!,
};

const _$TagPolarityEnumEnumMap = {
  TagPolarityEnum.good: 'good',
  TagPolarityEnum.bad: 'bad',
  TagPolarityEnum.neutral: 'neutral',
};
