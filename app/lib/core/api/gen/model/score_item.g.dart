// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'score_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ScoreItemCWProxy {
  ScoreItem id(String id);

  ScoreItem score(int score);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ScoreItem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ScoreItem(...).copyWith(id: 12, name: "My name")
  /// ```
  ScoreItem call({String id, int score});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfScoreItem.copyWith(...)` or call `instanceOfScoreItem.copyWith.fieldName(value)` for a single field.
class _$ScoreItemCWProxyImpl implements _$ScoreItemCWProxy {
  const _$ScoreItemCWProxyImpl(this._value);

  final ScoreItem _value;

  @override
  ScoreItem id(String id) => call(id: id);

  @override
  ScoreItem score(int score) => call(score: score);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ScoreItem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ScoreItem(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ScoreItem call({
    Object? id = const $CopyWithPlaceholder(),
    Object? score = const $CopyWithPlaceholder(),
  }) {
    return ScoreItem(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      score: score == const $CopyWithPlaceholder() || score == null
          ? _value.score
          // ignore: cast_nullable_to_non_nullable
          : score as int,
    );
  }
}

extension $ScoreItemCopyWith on ScoreItem {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfScoreItem.copyWith(...)` or `instanceOfScoreItem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ScoreItemCWProxy get copyWith => _$ScoreItemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScoreItem _$ScoreItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ScoreItem', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'score']);
      final val = ScoreItem(
        id: $checkedConvert('id', (v) => v as String),
        score: $checkedConvert('score', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$ScoreItemToJson(ScoreItem instance) => <String, dynamic>{
  'id': instance.id,
  'score': instance.score,
};
