// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiaryInputCWProxy {
  DiaryInput date(String date);

  DiaryInput body(String body);

  DiaryInput guideQuestion(GuideChoice? guideQuestion);

  DiaryInput withoutGuideQuestion(bool? withoutGuideQuestion);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryInput(...).copyWith(id: 12, name: "My name")
  /// ```
  DiaryInput call({
    String date,
    String body,
    GuideChoice? guideQuestion,
    bool? withoutGuideQuestion,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiaryInput.copyWith(...)` or call `instanceOfDiaryInput.copyWith.fieldName(value)` for a single field.
class _$DiaryInputCWProxyImpl implements _$DiaryInputCWProxy {
  const _$DiaryInputCWProxyImpl(this._value);

  final DiaryInput _value;

  @override
  DiaryInput date(String date) => call(date: date);

  @override
  DiaryInput body(String body) => call(body: body);

  @override
  DiaryInput guideQuestion(GuideChoice? guideQuestion) =>
      call(guideQuestion: guideQuestion);

  @override
  DiaryInput withoutGuideQuestion(bool? withoutGuideQuestion) =>
      call(withoutGuideQuestion: withoutGuideQuestion);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DiaryInput call({
    Object? date = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
    Object? guideQuestion = const $CopyWithPlaceholder(),
    Object? withoutGuideQuestion = const $CopyWithPlaceholder(),
  }) {
    return DiaryInput(
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
          : guideQuestion as GuideChoice?,
      withoutGuideQuestion: withoutGuideQuestion == const $CopyWithPlaceholder()
          ? _value.withoutGuideQuestion
          // ignore: cast_nullable_to_non_nullable
          : withoutGuideQuestion as bool?,
    );
  }
}

extension $DiaryInputCopyWith on DiaryInput {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDiaryInput.copyWith(...)` or `instanceOfDiaryInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiaryInputCWProxy get copyWith => _$DiaryInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiaryInput _$DiaryInputFromJson(Map<String, dynamic> json) => $checkedCreate(
  'DiaryInput',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['date', 'body']);
    final val = DiaryInput(
      date: $checkedConvert('date', (v) => v as String),
      body: $checkedConvert('body', (v) => v as String),
      guideQuestion: $checkedConvert(
        'guideQuestion',
        (v) =>
            v == null ? null : GuideChoice.fromJson(v as Map<String, dynamic>),
      ),
      withoutGuideQuestion: $checkedConvert(
        'withoutGuideQuestion',
        (v) => v as bool? ?? false,
      ),
    );
    return val;
  },
);

Map<String, dynamic> _$DiaryInputToJson(DiaryInput instance) =>
    <String, dynamic>{
      'date': instance.date,
      'body': instance.body,
      'guideQuestion': ?instance.guideQuestion?.toJson(),
      'withoutGuideQuestion': ?instance.withoutGuideQuestion,
    };
