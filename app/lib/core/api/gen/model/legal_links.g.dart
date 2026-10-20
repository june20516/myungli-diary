// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_links.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LegalLinksCWProxy {
  LegalLinks terms(String terms);

  LegalLinks privacy(String privacy);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LegalLinks(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LegalLinks(...).copyWith(id: 12, name: "My name")
  /// ```
  LegalLinks call({String terms, String privacy});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLegalLinks.copyWith(...)` or call `instanceOfLegalLinks.copyWith.fieldName(value)` for a single field.
class _$LegalLinksCWProxyImpl implements _$LegalLinksCWProxy {
  const _$LegalLinksCWProxyImpl(this._value);

  final LegalLinks _value;

  @override
  LegalLinks terms(String terms) => call(terms: terms);

  @override
  LegalLinks privacy(String privacy) => call(privacy: privacy);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LegalLinks(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LegalLinks(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LegalLinks call({
    Object? terms = const $CopyWithPlaceholder(),
    Object? privacy = const $CopyWithPlaceholder(),
  }) {
    return LegalLinks(
      terms: terms == const $CopyWithPlaceholder() || terms == null
          ? _value.terms
          // ignore: cast_nullable_to_non_nullable
          : terms as String,
      privacy: privacy == const $CopyWithPlaceholder() || privacy == null
          ? _value.privacy
          // ignore: cast_nullable_to_non_nullable
          : privacy as String,
    );
  }
}

extension $LegalLinksCopyWith on LegalLinks {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLegalLinks.copyWith(...)` or `instanceOfLegalLinks.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LegalLinksCWProxy get copyWith => _$LegalLinksCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LegalLinks _$LegalLinksFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LegalLinks', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['terms', 'privacy']);
      final val = LegalLinks(
        terms: $checkedConvert('terms', (v) => v as String),
        privacy: $checkedConvert('privacy', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$LegalLinksToJson(LegalLinks instance) =>
    <String, dynamic>{'terms': instance.terms, 'privacy': instance.privacy};
