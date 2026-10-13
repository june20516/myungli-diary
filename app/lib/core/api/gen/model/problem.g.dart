// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProblemCWProxy {
  Problem type(String type);

  Problem title(String title);

  Problem status(int status);

  Problem code(String code);

  Problem traceId(String traceId);

  Problem detail(String? detail);

  Problem errors(List<FieldError>? errors);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Problem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Problem(...).copyWith(id: 12, name: "My name")
  /// ```
  Problem call({
    String type,
    String title,
    int status,
    String code,
    String traceId,
    String? detail,
    List<FieldError>? errors,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProblem.copyWith(...)` or call `instanceOfProblem.copyWith.fieldName(value)` for a single field.
class _$ProblemCWProxyImpl implements _$ProblemCWProxy {
  const _$ProblemCWProxyImpl(this._value);

  final Problem _value;

  @override
  Problem type(String type) => call(type: type);

  @override
  Problem title(String title) => call(title: title);

  @override
  Problem status(int status) => call(status: status);

  @override
  Problem code(String code) => call(code: code);

  @override
  Problem traceId(String traceId) => call(traceId: traceId);

  @override
  Problem detail(String? detail) => call(detail: detail);

  @override
  Problem errors(List<FieldError>? errors) => call(errors: errors);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Problem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Problem(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Problem call({
    Object? type = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? code = const $CopyWithPlaceholder(),
    Object? traceId = const $CopyWithPlaceholder(),
    Object? detail = const $CopyWithPlaceholder(),
    Object? errors = const $CopyWithPlaceholder(),
  }) {
    return Problem(
      type: type == const $CopyWithPlaceholder() || type == null
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      title: title == const $CopyWithPlaceholder() || title == null
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      status: status == const $CopyWithPlaceholder() || status == null
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as int,
      code: code == const $CopyWithPlaceholder() || code == null
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      traceId: traceId == const $CopyWithPlaceholder() || traceId == null
          ? _value.traceId
          // ignore: cast_nullable_to_non_nullable
          : traceId as String,
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as String?,
      errors: errors == const $CopyWithPlaceholder()
          ? _value.errors
          // ignore: cast_nullable_to_non_nullable
          : errors as List<FieldError>?,
    );
  }
}

extension $ProblemCopyWith on Problem {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProblem.copyWith(...)` or `instanceOfProblem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProblemCWProxy get copyWith => _$ProblemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Problem _$ProblemFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Problem', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['type', 'title', 'status', 'code', 'traceId'],
      );
      final val = Problem(
        type: $checkedConvert('type', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        status: $checkedConvert('status', (v) => (v as num).toInt()),
        code: $checkedConvert('code', (v) => v as String),
        traceId: $checkedConvert('traceId', (v) => v as String),
        detail: $checkedConvert('detail', (v) => v as String?),
        errors: $checkedConvert(
          'errors',
          (v) => (v as List<dynamic>?)
              ?.map((e) => FieldError.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ProblemToJson(Problem instance) => <String, dynamic>{
  'type': instance.type,
  'title': instance.title,
  'status': instance.status,
  'code': instance.code,
  'traceId': instance.traceId,
  'detail': ?instance.detail,
  'errors': ?instance.errors?.map((e) => e.toJson()).toList(),
};
