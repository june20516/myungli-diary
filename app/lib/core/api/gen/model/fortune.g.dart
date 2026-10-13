// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fortune.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FortuneCWProxy {
  Fortune head(SlotText head);

  Fortune tag(SlotText? tag);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Fortune(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Fortune(...).copyWith(id: 12, name: "My name")
  /// ```
  Fortune call({SlotText head, SlotText? tag});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfFortune.copyWith(...)` or call `instanceOfFortune.copyWith.fieldName(value)` for a single field.
class _$FortuneCWProxyImpl implements _$FortuneCWProxy {
  const _$FortuneCWProxyImpl(this._value);

  final Fortune _value;

  @override
  Fortune head(SlotText head) => call(head: head);

  @override
  Fortune tag(SlotText? tag) => call(tag: tag);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Fortune(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Fortune(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Fortune call({
    Object? head = const $CopyWithPlaceholder(),
    Object? tag = const $CopyWithPlaceholder(),
  }) {
    return Fortune(
      head: head == const $CopyWithPlaceholder() || head == null
          ? _value.head
          // ignore: cast_nullable_to_non_nullable
          : head as SlotText,
      tag: tag == const $CopyWithPlaceholder()
          ? _value.tag
          // ignore: cast_nullable_to_non_nullable
          : tag as SlotText?,
    );
  }
}

extension $FortuneCopyWith on Fortune {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfFortune.copyWith(...)` or `instanceOfFortune.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FortuneCWProxy get copyWith => _$FortuneCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Fortune _$FortuneFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Fortune', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['head']);
      final val = Fortune(
        head: $checkedConvert(
          'head',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
        tag: $checkedConvert(
          'tag',
          (v) =>
              v == null ? null : SlotText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$FortuneToJson(Fortune instance) => <String, dynamic>{
  'head': instance.head.toJson(),
  'tag': ?instance.tag?.toJson(),
};
