// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiaryCWProxy {
  Diary date(String date);

  Diary body(String body);

  Diary guideQuestion(RenderedText? guideQuestion);

  Diary tags(DayTags tags);

  Diary rulesetVersion(String rulesetVersion);

  Diary createdAt(DateTime createdAt);

  Diary updatedAt(DateTime updatedAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Diary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Diary(...).copyWith(id: 12, name: "My name")
  /// ```
  Diary call({
    String date,
    String body,
    RenderedText? guideQuestion,
    DayTags tags,
    String rulesetVersion,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiary.copyWith(...)` or call `instanceOfDiary.copyWith.fieldName(value)` for a single field.
class _$DiaryCWProxyImpl implements _$DiaryCWProxy {
  const _$DiaryCWProxyImpl(this._value);

  final Diary _value;

  @override
  Diary date(String date) => call(date: date);

  @override
  Diary body(String body) => call(body: body);

  @override
  Diary guideQuestion(RenderedText? guideQuestion) =>
      call(guideQuestion: guideQuestion);

  @override
  Diary tags(DayTags tags) => call(tags: tags);

  @override
  Diary rulesetVersion(String rulesetVersion) =>
      call(rulesetVersion: rulesetVersion);

  @override
  Diary createdAt(DateTime createdAt) => call(createdAt: createdAt);

  @override
  Diary updatedAt(DateTime updatedAt) => call(updatedAt: updatedAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Diary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Diary(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Diary call({
    Object? date = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
    Object? guideQuestion = const $CopyWithPlaceholder(),
    Object? tags = const $CopyWithPlaceholder(),
    Object? rulesetVersion = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return Diary(
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String,
      body: body == const $CopyWithPlaceholder() || body == null
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      guideQuestion: guideQuestion == const $CopyWithPlaceholder()
          ? _value.guideQuestion
          // ignore: cast_nullable_to_non_nullable
          : guideQuestion as RenderedText?,
      tags: tags == const $CopyWithPlaceholder() || tags == null
          ? _value.tags
          // ignore: cast_nullable_to_non_nullable
          : tags as DayTags,
      rulesetVersion:
          rulesetVersion == const $CopyWithPlaceholder() ||
              rulesetVersion == null
          ? _value.rulesetVersion
          // ignore: cast_nullable_to_non_nullable
          : rulesetVersion as String,
      createdAt: createdAt == const $CopyWithPlaceholder() || createdAt == null
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      updatedAt: updatedAt == const $CopyWithPlaceholder() || updatedAt == null
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $DiaryCopyWith on Diary {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDiary.copyWith(...)` or `instanceOfDiary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiaryCWProxy get copyWith => _$DiaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Diary _$DiaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('Diary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'date',
      'body',
      'tags',
      'rulesetVersion',
      'createdAt',
      'updatedAt',
    ],
  );
  final val = Diary(
    date: $checkedConvert('date', (v) => v as String),
    body: $checkedConvert('body', (v) => v as String),
    guideQuestion: $checkedConvert(
      'guideQuestion',
      (v) =>
          v == null ? null : RenderedText.fromJson(v as Map<String, dynamic>),
    ),
    tags: $checkedConvert(
      'tags',
      (v) => DayTags.fromJson(v as Map<String, dynamic>),
    ),
    rulesetVersion: $checkedConvert('rulesetVersion', (v) => v as String),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$DiaryToJson(Diary instance) => <String, dynamic>{
  'date': instance.date,
  'body': instance.body,
  'guideQuestion': ?instance.guideQuestion?.toJson(),
  'tags': instance.tags.toJson(),
  'rulesetVersion': instance.rulesetVersion,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
