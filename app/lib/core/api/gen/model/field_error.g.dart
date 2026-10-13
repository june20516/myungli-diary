// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'field_error.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FieldErrorCWProxy {
  FieldError field(String field);

  FieldError code(String code);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FieldError(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FieldError(...).copyWith(id: 12, name: "My name")
  /// ```
  FieldError call({String field, String code});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfFieldError.copyWith(...)` or call `instanceOfFieldError.copyWith.fieldName(value)` for a single field.
class _$FieldErrorCWProxyImpl implements _$FieldErrorCWProxy {
  const _$FieldErrorCWProxyImpl(this._value);

  final FieldError _value;

  @override
  FieldError field(String field) => call(field: field);

  @override
  FieldError code(String code) => call(code: code);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FieldError(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FieldError(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  FieldError call({
    Object? field = const $CopyWithPlaceholder(),
    Object? code = const $CopyWithPlaceholder(),
  }) {
    return FieldError(
      field: field == const $CopyWithPlaceholder() || field == null
          ? _value.field
          // ignore: cast_nullable_to_non_nullable
          : field as String,
      code: code == const $CopyWithPlaceholder() || code == null
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
    );
  }
}

extension $FieldErrorCopyWith on FieldError {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfFieldError.copyWith(...)` or `instanceOfFieldError.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FieldErrorCWProxy get copyWith => _$FieldErrorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FieldError _$FieldErrorFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FieldError', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['field', 'code']);
      final val = FieldError(
        field: $checkedConvert('field', (v) => v as String),
        code: $checkedConvert('code', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$FieldErrorToJson(FieldError instance) =>
    <String, dynamic>{'field': instance.field, 'code': instance.code};
