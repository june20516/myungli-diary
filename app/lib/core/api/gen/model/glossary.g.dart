// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glossary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GlossaryCWProxy {
  Glossary seedVersion(String seedVersion);

  Glossary lang(Language lang);

  Glossary values(Map<String, Map<String, String>> values);

  Glossary meanings(Map<String, RenderedText> meanings);

  Glossary hanja(Map<String, String> hanja);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Glossary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Glossary(...).copyWith(id: 12, name: "My name")
  /// ```
  Glossary call({
    String seedVersion,
    Language lang,
    Map<String, Map<String, String>> values,
    Map<String, RenderedText> meanings,
    Map<String, String> hanja,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGlossary.copyWith(...)` or call `instanceOfGlossary.copyWith.fieldName(value)` for a single field.
class _$GlossaryCWProxyImpl implements _$GlossaryCWProxy {
  const _$GlossaryCWProxyImpl(this._value);

  final Glossary _value;

  @override
  Glossary seedVersion(String seedVersion) => call(seedVersion: seedVersion);

  @override
  Glossary lang(Language lang) => call(lang: lang);

  @override
  Glossary values(Map<String, Map<String, String>> values) =>
      call(values: values);

  @override
  Glossary meanings(Map<String, RenderedText> meanings) =>
      call(meanings: meanings);

  @override
  Glossary hanja(Map<String, String> hanja) => call(hanja: hanja);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Glossary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Glossary(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Glossary call({
    Object? seedVersion = const $CopyWithPlaceholder(),
    Object? lang = const $CopyWithPlaceholder(),
    Object? values = const $CopyWithPlaceholder(),
    Object? meanings = const $CopyWithPlaceholder(),
    Object? hanja = const $CopyWithPlaceholder(),
  }) {
    return Glossary(
      seedVersion:
          seedVersion == const $CopyWithPlaceholder() || seedVersion == null
          ? _value.seedVersion
          // ignore: cast_nullable_to_non_nullable
          : seedVersion as String,
      lang: lang == const $CopyWithPlaceholder() || lang == null
          ? _value.lang
          // ignore: cast_nullable_to_non_nullable
          : lang as Language,
      values: values == const $CopyWithPlaceholder() || values == null
          ? _value.values
          // ignore: cast_nullable_to_non_nullable
          : values as Map<String, Map<String, String>>,
      meanings: meanings == const $CopyWithPlaceholder() || meanings == null
          ? _value.meanings
          // ignore: cast_nullable_to_non_nullable
          : meanings as Map<String, RenderedText>,
      hanja: hanja == const $CopyWithPlaceholder() || hanja == null
          ? _value.hanja
          // ignore: cast_nullable_to_non_nullable
          : hanja as Map<String, String>,
    );
  }
}

extension $GlossaryCopyWith on Glossary {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGlossary.copyWith(...)` or `instanceOfGlossary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GlossaryCWProxy get copyWith => _$GlossaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Glossary _$GlossaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('Glossary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['seedVersion', 'lang', 'values', 'meanings', 'hanja'],
  );
  final val = Glossary(
    seedVersion: $checkedConvert('seedVersion', (v) => v as String),
    lang: $checkedConvert('lang', (v) => $enumDecode(_$LanguageEnumMap, v)),
    values: $checkedConvert(
      'values',
      (v) => (v as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, String>.from(e as Map)),
      ),
    ),
    meanings: $checkedConvert(
      'meanings',
      (v) => (v as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, RenderedText.fromJson(e as Map<String, dynamic>)),
      ),
    ),
    hanja: $checkedConvert('hanja', (v) => Map<String, String>.from(v as Map)),
  );
  return val;
});

Map<String, dynamic> _$GlossaryToJson(Glossary instance) => <String, dynamic>{
  'seedVersion': instance.seedVersion,
  'lang': _$LanguageEnumMap[instance.lang]!,
  'values': instance.values,
  'meanings': instance.meanings.map((k, e) => MapEntry(k, e.toJson())),
  'hanja': instance.hanja,
};

const _$LanguageEnumMap = {
  Language.ko: 'ko',
  Language.en: 'en',
  Language.ja: 'ja',
};
