// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_document.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConsentDocumentCWProxy {
  ConsentDocument document(ConsentDocumentDocumentEnum document);

  ConsentDocument version(String version);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConsentDocument(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConsentDocument(...).copyWith(id: 12, name: "My name")
  /// ```
  ConsentDocument call({ConsentDocumentDocumentEnum document, String version});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfConsentDocument.copyWith(...)` or call `instanceOfConsentDocument.copyWith.fieldName(value)` for a single field.
class _$ConsentDocumentCWProxyImpl implements _$ConsentDocumentCWProxy {
  const _$ConsentDocumentCWProxyImpl(this._value);

  final ConsentDocument _value;

  @override
  ConsentDocument document(ConsentDocumentDocumentEnum document) =>
      call(document: document);

  @override
  ConsentDocument version(String version) => call(version: version);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConsentDocument(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConsentDocument(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ConsentDocument call({
    Object? document = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return ConsentDocument(
      document: document == const $CopyWithPlaceholder() || document == null
          ? _value.document
          // ignore: cast_nullable_to_non_nullable
          : document as ConsentDocumentDocumentEnum,
      version: version == const $CopyWithPlaceholder() || version == null
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as String,
    );
  }
}

extension $ConsentDocumentCopyWith on ConsentDocument {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfConsentDocument.copyWith(...)` or `instanceOfConsentDocument.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConsentDocumentCWProxy get copyWith => _$ConsentDocumentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsentDocument _$ConsentDocumentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ConsentDocument', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['document', 'version']);
      final val = ConsentDocument(
        document: $checkedConvert(
          'document',
          (v) => $enumDecode(_$ConsentDocumentDocumentEnumEnumMap, v),
        ),
        version: $checkedConvert('version', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ConsentDocumentToJson(ConsentDocument instance) =>
    <String, dynamic>{
      'document': _$ConsentDocumentDocumentEnumEnumMap[instance.document]!,
      'version': instance.version,
    };

const _$ConsentDocumentDocumentEnumEnumMap = {
  ConsentDocumentDocumentEnum.terms: 'terms',
  ConsentDocumentDocumentEnum.privacy: 'privacy',
};
