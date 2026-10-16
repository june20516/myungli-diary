//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'glossary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Glossary {
  /// Returns a new [Glossary] instance.
  Glossary({
    required this.seedVersion,

    required this.lang,

    required this.values,

    required this.meanings,
  });

  @JsonKey(name: r'seedVersion', required: true, includeIfNull: false)
  final String seedVersion;

  @JsonKey(name: r'lang', required: true, includeIfNull: false)
  final Language lang;

  /// 범주 → (값 → 이름). 범주는 writing `glossary.value_name` 키의 `<범주>`, 그리고 `tag`·`focus_reason`·`score_item`·`solar_term`입니다.
  @JsonKey(name: r'values', required: true, includeIfNull: false)
  final Map<String, Map<String, String>> values;

  /// 용어 id → 뜻 문장(writing 슬롯 `term.meaning`, 키 `term.<용어 id>`)
  @JsonKey(name: r'meanings', required: true, includeIfNull: false)
  final Map<String, RenderedText> meanings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Glossary &&
          other.seedVersion == seedVersion &&
          other.lang == lang &&
          other.values == values &&
          other.meanings == meanings;

  @override
  int get hashCode =>
      seedVersion.hashCode +
      lang.hashCode +
      values.hashCode +
      meanings.hashCode;

  factory Glossary.fromJson(Map<String, dynamic> json) =>
      _$GlossaryFromJson(json);

  Map<String, dynamic> toJson() => _$GlossaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
