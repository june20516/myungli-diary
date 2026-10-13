//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tag.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Tag {
  /// Returns a new [Tag] instance.
  Tag({required this.key, required this.polarity});

  /// 태그 키(glossary `tag` 범주의 키)
  @JsonKey(name: r'key', required: true, includeIfNull: false)
  final String key;

  /// 태그의 길흉. 엔진 spec §7.7 표의 값입니다.
  @JsonKey(name: r'polarity', required: true, includeIfNull: false)
  final TagPolarityEnum polarity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && other.key == key && other.polarity == polarity;

  @override
  int get hashCode => key.hashCode + polarity.hashCode;

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

  Map<String, dynamic> toJson() => _$TagToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

/// 태그의 길흉. 엔진 spec §7.7 표의 값입니다.
enum TagPolarityEnum {
  @JsonValue(r'good')
  good(r'good'),
  @JsonValue(r'bad')
  bad(r'bad'),
  @JsonValue(r'neutral')
  neutral(r'neutral');

  const TagPolarityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
