// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'segment.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SegmentCWProxy {
  Segment text(String text);

  Segment term(String? term);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Segment(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Segment(...).copyWith(id: 12, name: "My name")
  /// ```
  Segment call({String text, String? term});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSegment.copyWith(...)` or call `instanceOfSegment.copyWith.fieldName(value)` for a single field.
class _$SegmentCWProxyImpl implements _$SegmentCWProxy {
  const _$SegmentCWProxyImpl(this._value);

  final Segment _value;

  @override
  Segment text(String text) => call(text: text);

  @override
  Segment term(String? term) => call(term: term);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Segment(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Segment(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Segment call({
    Object? text = const $CopyWithPlaceholder(),
    Object? term = const $CopyWithPlaceholder(),
  }) {
    return Segment(
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as String,
      term: term == const $CopyWithPlaceholder()
          ? _value.term
          // ignore: cast_nullable_to_non_nullable
          : term as String?,
    );
  }
}

extension $SegmentCopyWith on Segment {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSegment.copyWith(...)` or `instanceOfSegment.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SegmentCWProxy get copyWith => _$SegmentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Segment _$SegmentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Segment', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['text']);
      final val = Segment(
        text: $checkedConvert('text', (v) => v as String),
        term: $checkedConvert('term', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SegmentToJson(Segment instance) => <String, dynamic>{
  'text': instance.text,
  'term': ?instance.term,
};
