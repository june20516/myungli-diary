// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_body_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiaryBodyInputCWProxy {
  DiaryBodyInput body(String body);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryBodyInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryBodyInput(...).copyWith(id: 12, name: "My name")
  /// ```
  DiaryBodyInput call({String body});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDiaryBodyInput.copyWith(...)` or call `instanceOfDiaryBodyInput.copyWith.fieldName(value)` for a single field.
class _$DiaryBodyInputCWProxyImpl implements _$DiaryBodyInputCWProxy {
  const _$DiaryBodyInputCWProxyImpl(this._value);

  final DiaryBodyInput _value;

  @override
  DiaryBodyInput body(String body) => call(body: body);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DiaryBodyInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DiaryBodyInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DiaryBodyInput call({Object? body = const $CopyWithPlaceholder()}) {
    return DiaryBodyInput(
      body: body == const $CopyWithPlaceholder() || body == null
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
    );
  }
}

extension $DiaryBodyInputCopyWith on DiaryBodyInput {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDiaryBodyInput.copyWith(...)` or `instanceOfDiaryBodyInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiaryBodyInputCWProxy get copyWith => _$DiaryBodyInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiaryBodyInput _$DiaryBodyInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiaryBodyInput', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['body']);
      final val = DiaryBodyInput(
        body: $checkedConvert('body', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$DiaryBodyInputToJson(DiaryBodyInput instance) =>
    <String, dynamic>{'body': instance.body};
