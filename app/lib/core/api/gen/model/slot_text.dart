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

  @JsonKey(name: r'variant', required: true, includeIfNull: false)
  final SlotTextVariantEnum variant;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final RenderedText text;

  @JsonKey(name: r'reactable', required: true, includeIfNull: false)
  final bool reactable;

  /// 이 사용자가 남긴 반응. 반응이 없으면 생략합니다.
  @JsonKey(name: r'reaction', required: false, includeIfNull: false)
  final SlotTextReactionEnum? reaction;

  @JsonKey(name: r'todayReason', required: false, includeIfNull: false)
  final RenderedText? todayReason;

  /// 판정 근거. 응답의 `evidenceAccess`가 `unlocked`일 때만 담깁니다.
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
  single(r'single');

  const SlotTextVariantEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

/// 이 사용자가 남긴 반응. 반응이 없으면 생략합니다.
enum SlotTextReactionEnum {
  @JsonValue(r'like')
  like(r'like');

  const SlotTextReactionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
