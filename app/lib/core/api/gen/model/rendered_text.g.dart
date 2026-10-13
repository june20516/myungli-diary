// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rendered_text.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RenderedTextCWProxy {
  RenderedText segments(List<Segment> segments);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RenderedText(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RenderedText(...).copyWith(id: 12, name: "My name")
  /// ```
  RenderedText call({List<Segment> segments});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfRenderedText.copyWith(...)` or call `instanceOfRenderedText.copyWith.fieldName(value)` for a single field.
class _$RenderedTextCWProxyImpl implements _$RenderedTextCWProxy {
  const _$RenderedTextCWProxyImpl(this._value);

  final RenderedText _value;

  @override
  RenderedText segments(List<Segment> segments) => call(segments: segments);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RenderedText(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RenderedText(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  RenderedText call({Object? segments = const $CopyWithPlaceholder()}) {
    return RenderedText(
      segments: segments == const $CopyWithPlaceholder() || segments == null
          ? _value.segments
          // ignore: cast_nullable_to_non_nullable
          : segments as List<Segment>,
    );
  }
}

extension $RenderedTextCopyWith on RenderedText {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfRenderedText.copyWith(...)` or `instanceOfRenderedText.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RenderedTextCWProxy get copyWith => _$RenderedTextCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RenderedText _$RenderedTextFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RenderedText', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['segments']);
      final val = RenderedText(
        segments: $checkedConvert(
          'segments',
          (v) => (v as List<dynamic>)
              .map((e) => Segment.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$RenderedTextToJson(RenderedText instance) =>
    <String, dynamic>{
      'segments': instance.segments.map((e) => e.toJson()).toList(),
    };
