// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConsentRequestCWProxy {
  ConsentRequest documents(List<ConsentDocument> documents);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConsentRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConsentRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  ConsentRequest call({List<ConsentDocument> documents});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfConsentRequest.copyWith(...)` or call `instanceOfConsentRequest.copyWith.fieldName(value)` for a single field.
class _$ConsentRequestCWProxyImpl implements _$ConsentRequestCWProxy {
  const _$ConsentRequestCWProxyImpl(this._value);

  final ConsentRequest _value;

  @override
  ConsentRequest documents(List<ConsentDocument> documents) =>
      call(documents: documents);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConsentRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConsentRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ConsentRequest call({Object? documents = const $CopyWithPlaceholder()}) {
    return ConsentRequest(
      documents: documents == const $CopyWithPlaceholder() || documents == null
          ? _value.documents
          // ignore: cast_nullable_to_non_nullable
          : documents as List<ConsentDocument>,
    );
  }
}

extension $ConsentRequestCopyWith on ConsentRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfConsentRequest.copyWith(...)` or `instanceOfConsentRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConsentRequestCWProxy get copyWith => _$ConsentRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsentRequest _$ConsentRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ConsentRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['documents']);
      final val = ConsentRequest(
        documents: $checkedConvert(
          'documents',
          (v) => (v as List<dynamic>)
              .map((e) => ConsentDocument.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ConsentRequestToJson(ConsentRequest instance) =>
    <String, dynamic>{
      'documents': instance.documents.map((e) => e.toJson()).toList(),
    };
