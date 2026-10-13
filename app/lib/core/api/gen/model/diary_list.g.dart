// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiaryListCWProxy {
  DiaryList items(List<DiarySummary> items);

  DiaryList nextCursor(String? nextCursor);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryList(...).copyWith(id: 12, name: "My name")
  /// ```
  DiaryList call({List<DiarySummary> items, String? nextCursor});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiaryList.copyWith(...)` or call `instanceOfDiaryList.copyWith.fieldName(value)` for a single field.
class _$DiaryListCWProxyImpl implements _$DiaryListCWProxy {
  const _$DiaryListCWProxyImpl(this._value);

  final DiaryList _value;

  @override
  DiaryList items(List<DiarySummary> items) => call(items: items);

  @override
  DiaryList nextCursor(String? nextCursor) => call(nextCursor: nextCursor);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryList(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryList(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DiaryList call({
    Object? items = const $CopyWithPlaceholder(),
    Object? nextCursor = const $CopyWithPlaceholder(),
  }) {
    return DiaryList(
      items: items == const $CopyWithPlaceholder() || items == null
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<DiarySummary>,
      nextCursor: nextCursor == const $CopyWithPlaceholder()
          ? _value.nextCursor
          // ignore: cast_nullable_to_non_nullable
          : nextCursor as String?,
    );
  }
}

extension $DiaryListCopyWith on DiaryList {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDiaryList.copyWith(...)` or `instanceOfDiaryList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiaryListCWProxy get copyWith => _$DiaryListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiaryList _$DiaryListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiaryList', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['items']);
      final val = DiaryList(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => DiarySummary.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        nextCursor: $checkedConvert('nextCursor', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$DiaryListToJson(DiaryList instance) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'nextCursor': ?instance.nextCursor,
};
