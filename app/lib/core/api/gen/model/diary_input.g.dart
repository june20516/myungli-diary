// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiaryInputCWProxy {
  DiaryInput body(String body);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryInput(...).copyWith(id: 12, name: "My name")
  /// ```
  DiaryInput call({String body});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiaryInput.copyWith(...)` or call `instanceOfDiaryInput.copyWith.fieldName(value)` for a single field.
class _$DiaryInputCWProxyImpl implements _$DiaryInputCWProxy {
  const _$DiaryInputCWProxyImpl(this._value);

  final DiaryInput _value;

  @override
  DiaryInput body(String body) => call(body: body);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DiaryInput call({Object? body = const $CopyWithPlaceholder()}) {
    return DiaryInput(
      body: body == const $CopyWithPlaceholder() || body == null
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
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

DiaryInput _$DiaryInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiaryInput', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['body']);
      final val = DiaryInput(body: $checkedConvert('body', (v) => v as String));
      return val;
    });

Map<String, dynamic> _$DiaryInputToJson(DiaryInput instance) =>
    <String, dynamic>{'body': instance.body};
