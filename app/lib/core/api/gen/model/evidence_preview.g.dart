// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EvidencePreviewCWProxy {
  EvidencePreview basis(RenderedText? basis);

  EvidencePreview source_(RenderedText? source_);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EvidencePreview(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EvidencePreview(...).copyWith(id: 12, name: "My name")
  /// ```
  EvidencePreview call({RenderedText? basis, RenderedText? source_});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfEvidencePreview.copyWith(...)` or call `instanceOfEvidencePreview.copyWith.fieldName(value)` for a single field.
class _$EvidencePreviewCWProxyImpl implements _$EvidencePreviewCWProxy {
  const _$EvidencePreviewCWProxyImpl(this._value);

  final EvidencePreview _value;

  @override
  EvidencePreview basis(RenderedText? basis) => call(basis: basis);

  @override
  EvidencePreview source_(RenderedText? source_) => call(source_: source_);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EvidencePreview(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EvidencePreview(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  EvidencePreview call({
    Object? basis = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
  }) {
    return EvidencePreview(
      basis: basis == const $CopyWithPlaceholder()
          ? _value.basis
          // ignore: cast_nullable_to_non_nullable
          : basis as RenderedText?,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as RenderedText?,
    );
  }
}

extension $EvidencePreviewCopyWith on EvidencePreview {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfEvidencePreview.copyWith(...)` or `instanceOfEvidencePreview.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EvidencePreviewCWProxy get copyWith => _$EvidencePreviewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvidencePreview _$EvidencePreviewFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('EvidencePreview', json, ($checkedConvert) {
  final val = EvidencePreview(
    basis: $checkedConvert(
      'basis',
      (v) =>
          v == null ? null : RenderedText.fromJson(v as Map<String, dynamic>),
    ),
    source_: $checkedConvert(
      'source',
      (v) =>
          v == null ? null : RenderedText.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
}, fieldKeyMap: const {'source_': 'source'});

Map<String, dynamic> _$EvidencePreviewToJson(EvidencePreview instance) =>
    <String, dynamic>{
      'basis': ?instance.basis?.toJson(),
      'source': ?instance.source_?.toJson(),
    };
