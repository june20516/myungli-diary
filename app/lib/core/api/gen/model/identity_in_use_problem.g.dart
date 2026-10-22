// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_in_use_problem.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$IdentityInUseProblemCWProxy {
  IdentityInUseProblem type(String type);

  IdentityInUseProblem title(String title);

  IdentityInUseProblem status(int status);

  IdentityInUseProblem code(String code);

  IdentityInUseProblem traceId(String traceId);

  IdentityInUseProblem detail(String? detail);

  IdentityInUseProblem errors(List<FieldError>? errors);

  IdentityInUseProblem mergeToken(String? mergeToken);

  IdentityInUseProblem expiresAt(DateTime? expiresAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `IdentityInUseProblem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// IdentityInUseProblem(...).copyWith(id: 12, name: "My name")
  /// ```
  IdentityInUseProblem call({
    String type,
    String title,
    int status,
    String code,
    String traceId,
    String? detail,
    List<FieldError>? errors,
    String? mergeToken,
    DateTime? expiresAt,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfIdentityInUseProblem.copyWith(...)` or call `instanceOfIdentityInUseProblem.copyWith.fieldName(value)` for a single field.
class _$IdentityInUseProblemCWProxyImpl
    implements _$IdentityInUseProblemCWProxy {
  const _$IdentityInUseProblemCWProxyImpl(this._value);

  final IdentityInUseProblem _value;

  @override
  IdentityInUseProblem type(String type) => call(type: type);

  @override
  IdentityInUseProblem title(String title) => call(title: title);

  @override
  IdentityInUseProblem status(int status) => call(status: status);

  @override
  IdentityInUseProblem code(String code) => call(code: code);

  @override
  IdentityInUseProblem traceId(String traceId) => call(traceId: traceId);

  @override
  IdentityInUseProblem detail(String? detail) => call(detail: detail);

  @override
  IdentityInUseProblem errors(List<FieldError>? errors) => call(errors: errors);

  @override
  IdentityInUseProblem mergeToken(String? mergeToken) =>
      call(mergeToken: mergeToken);

  @override
  IdentityInUseProblem expiresAt(DateTime? expiresAt) =>
      call(expiresAt: expiresAt);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `IdentityInUseProblem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// IdentityInUseProblem(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  IdentityInUseProblem call({
    Object? type = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? code = const $CopyWithPlaceholder(),
    Object? traceId = const $CopyWithPlaceholder(),
    Object? detail = const $CopyWithPlaceholder(),
    Object? errors = const $CopyWithPlaceholder(),
    Object? mergeToken = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
  }) {
    return IdentityInUseProblem(
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
      mergeToken: mergeToken == const $CopyWithPlaceholder()
          ? _value.mergeToken
          // ignore: cast_nullable_to_non_nullable
          : mergeToken as String?,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
    );
  }
}

extension $IdentityInUseProblemCopyWith on IdentityInUseProblem {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfIdentityInUseProblem.copyWith(...)` or `instanceOfIdentityInUseProblem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$IdentityInUseProblemCWProxy get copyWith =>
      _$IdentityInUseProblemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentityInUseProblem _$IdentityInUseProblemFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('IdentityInUseProblem', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['type', 'title', 'status', 'code', 'traceId'],
  );
  final val = IdentityInUseProblem(
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
    mergeToken: $checkedConvert('mergeToken', (v) => v as String?),
    expiresAt: $checkedConvert(
      'expiresAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$IdentityInUseProblemToJson(
  IdentityInUseProblem instance,
) => <String, dynamic>{
  'type': instance.type,
  'title': instance.title,
  'status': instance.status,
  'code': instance.code,
  'traceId': instance.traceId,
  'detail': ?instance.detail,
  'errors': ?instance.errors?.map((e) => e.toJson()).toList(),
  'mergeToken': ?instance.mergeToken,
  'expiresAt': ?instance.expiresAt?.toIso8601String(),
};
