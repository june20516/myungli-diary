//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'slot_text.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SlotText {
  /// Returns a new [SlotText] instance.
  SlotText({
    required this.slot,

    required this.messageKey,

    required this.variant,

    required this.text,

    required this.reactable,

    this.reaction,

    this.todayReason,

    this.evidence,
  });

  /// writing 슬롯 id(예 `daily.fortune.head`)
  @JsonKey(name: r'slot', required: true, includeIfNull: false)
  final String slot;

  @JsonKey(name: r'messageKey', required: true, includeIfNull: false)
  final String messageKey;

  @JsonKey(
    name: r'variant',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SlotTextVariantEnum.unknownDefaultOpenApi,
  )
  final SlotTextVariantEnum variant;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final RenderedText text;

  @JsonKey(name: r'reactable', required: true, includeIfNull: false)
  final bool reactable;

  /// 이 사용자가 남긴 반응. 반응이 없으면 생략합니다. 열린 enum이라 app은 모르는 값이면 반응이 없는 것으로 표시합니다.
  @JsonKey(
    name: r'reaction',
    required: false,
    includeIfNull: false,
    unknownEnumValue: SlotTextReactionEnum.unknownDefaultOpenApi,
  )
  final SlotTextReactionEnum? reaction;

  @JsonKey(name: r'todayReason', required: false, includeIfNull: false)
  final RenderedText? todayReason;

  /// 판정 근거. 응답의 `evidenceAccess`가 `unlocked`이고 근거가 있을 때만 담깁니다. 빈 배열은 보내지 않습니다.
  @JsonKey(name: r'evidence', required: false, includeIfNull: false)
  final List<Evidence>? evidence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotText &&
          other.slot == slot &&
          other.messageKey == messageKey &&
          other.variant == variant &&
          other.text == text &&
          other.reactable == reactable &&
          other.reaction == reaction &&
          other.todayReason == todayReason &&
          other.evidence == evidence;

  @override
  int get hashCode =>
      slot.hashCode +
      messageKey.hashCode +
      variant.hashCode +
      text.hashCode +
      reactable.hashCode +
      reaction.hashCode +
      todayReason.hashCode +
      evidence.hashCode;

  factory SlotText.fromJson(Map<String, dynamic> json) =>
      _$SlotTextFromJson(json);

  Map<String, dynamic> toJson() => _$SlotTextToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SlotTextVariantEnum {
  @JsonValue(r'advice')
  advice(r'advice'),
  @JsonValue(r'state')
  state(r'state'),
  @JsonValue(r'care')
  care(r'care'),
  @JsonValue(r'1')
  n1(r'1'),
  @JsonValue(r'2')
  n2(r'2'),
  @JsonValue(r'single')
  single(r'single'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SlotTextVariantEnum(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}

/// 이 사용자가 남긴 반응. 반응이 없으면 생략합니다. 열린 enum이라 app은 모르는 값이면 반응이 없는 것으로 표시합니다.
enum SlotTextReactionEnum {
  @JsonValue(r'like')
  like(r'like'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SlotTextReactionEnum(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
