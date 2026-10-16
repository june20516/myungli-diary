// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EvidenceCWProxy {
  Evidence ruleId(String ruleId);

  Evidence sourceRef(String sourceRef);

  Evidence detail(Map<String, String>? detail);

  Evidence basis(RenderedText? basis);

  Evidence source_(RenderedText? source_);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Evidence(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Evidence(...).copyWith(id: 12, name: "My name")
  /// ```
  Evidence call({
    String ruleId,
    String sourceRef,
    Map<String, String>? detail,
    RenderedText? basis,
    RenderedText? source_,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfEvidence.copyWith(...)` or call `instanceOfEvidence.copyWith.fieldName(value)` for a single field.
class _$EvidenceCWProxyImpl implements _$EvidenceCWProxy {
  const _$EvidenceCWProxyImpl(this._value);

  final Evidence _value;

  @override
  Evidence ruleId(String ruleId) => call(ruleId: ruleId);

  @override
  Evidence sourceRef(String sourceRef) => call(sourceRef: sourceRef);

  @override
  Evidence detail(Map<String, String>? detail) => call(detail: detail);

  @override
  Evidence basis(RenderedText? basis) => call(basis: basis);

  @override
  Evidence source_(RenderedText? source_) => call(source_: source_);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Evidence(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Evidence(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Evidence call({
    Object? ruleId = const $CopyWithPlaceholder(),
    Object? sourceRef = const $CopyWithPlaceholder(),
    Object? detail = const $CopyWithPlaceholder(),
    Object? basis = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
  }) {
    return Evidence(
      ruleId: ruleId == const $CopyWithPlaceholder() || ruleId == null
          ? _value.ruleId
          // ignore: cast_nullable_to_non_nullable
          : ruleId as String,
      sourceRef: sourceRef == const $CopyWithPlaceholder() || sourceRef == null
          ? _value.sourceRef
          // ignore: cast_nullable_to_non_nullable
          : sourceRef as String,
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as Map<String, String>?,
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

extension $EvidenceCopyWith on Evidence {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfEvidence.copyWith(...)` or `instanceOfEvidence.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EvidenceCWProxy get copyWith => _$EvidenceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Evidence _$EvidenceFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('Evidence', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['ruleId', 'sourceRef']);
  final val = Evidence(
    ruleId: $checkedConvert('ruleId', (v) => v as String),
    sourceRef: $checkedConvert('sourceRef', (v) => v as String),
    detail: $checkedConvert(
      'detail',
      (v) =>
          (v as Map<String, dynamic>?)?.map((k, e) => MapEntry(k, e as String)),
    ),
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

Map<String, dynamic> _$EvidenceToJson(Evidence instance) => <String, dynamic>{
  'ruleId': instance.ruleId,
  'sourceRef': instance.sourceRef,
  'detail': ?instance.detail,
  'basis': ?instance.basis?.toJson(),
  'source': ?instance.source_?.toJson(),
};
