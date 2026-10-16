// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slot_text.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SlotTextCWProxy {
  SlotText slot(String slot);

  SlotText messageKey(String messageKey);

  SlotText variant(SlotTextVariantEnum variant);

  SlotText text(RenderedText text);

  SlotText reactable(bool reactable);

  SlotText reaction(SlotTextReactionEnum? reaction);

  SlotText todayReason(RenderedText? todayReason);

  SlotText evidence(List<Evidence>? evidence);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SlotText(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SlotText(...).copyWith(id: 12, name: "My name")
  /// ```
  SlotText call({
    String slot,
    String messageKey,
    SlotTextVariantEnum variant,
    RenderedText text,
    bool reactable,
    SlotTextReactionEnum? reaction,
    RenderedText? todayReason,
    List<Evidence>? evidence,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSlotText.copyWith(...)` or call `instanceOfSlotText.copyWith.fieldName(value)` for a single field.
class _$SlotTextCWProxyImpl implements _$SlotTextCWProxy {
  const _$SlotTextCWProxyImpl(this._value);

  final SlotText _value;

  @override
  SlotText slot(String slot) => call(slot: slot);

  @override
  SlotText messageKey(String messageKey) => call(messageKey: messageKey);

  @override
  SlotText variant(SlotTextVariantEnum variant) => call(variant: variant);

  @override
  SlotText text(RenderedText text) => call(text: text);

  @override
  SlotText reactable(bool reactable) => call(reactable: reactable);

  @override
  SlotText reaction(SlotTextReactionEnum? reaction) => call(reaction: reaction);

  @override
  SlotText todayReason(RenderedText? todayReason) =>
      call(todayReason: todayReason);

  @override
  SlotText evidence(List<Evidence>? evidence) => call(evidence: evidence);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SlotText(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SlotText(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SlotText call({
    Object? slot = const $CopyWithPlaceholder(),
    Object? messageKey = const $CopyWithPlaceholder(),
    Object? variant = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
    Object? reactable = const $CopyWithPlaceholder(),
    Object? reaction = const $CopyWithPlaceholder(),
    Object? todayReason = const $CopyWithPlaceholder(),
    Object? evidence = const $CopyWithPlaceholder(),
  }) {
    return SlotText(
      slot: slot == const $CopyWithPlaceholder() || slot == null
          ? _value.slot
          // ignore: cast_nullable_to_non_nullable
          : slot as String,
      messageKey:
          messageKey == const $CopyWithPlaceholder() || messageKey == null
          ? _value.messageKey
          // ignore: cast_nullable_to_non_nullable
          : messageKey as String,
      variant: variant == const $CopyWithPlaceholder() || variant == null
          ? _value.variant
          // ignore: cast_nullable_to_non_nullable
          : variant as SlotTextVariantEnum,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as RenderedText,
      reactable: reactable == const $CopyWithPlaceholder() || reactable == null
          ? _value.reactable
          // ignore: cast_nullable_to_non_nullable
          : reactable as bool,
      reaction: reaction == const $CopyWithPlaceholder()
          ? _value.reaction
          // ignore: cast_nullable_to_non_nullable
          : reaction as SlotTextReactionEnum?,
      todayReason: todayReason == const $CopyWithPlaceholder()
          ? _value.todayReason
          // ignore: cast_nullable_to_non_nullable
          : todayReason as RenderedText?,
      evidence: evidence == const $CopyWithPlaceholder()
          ? _value.evidence
          // ignore: cast_nullable_to_non_nullable
          : evidence as List<Evidence>?,
    );
  }
}

extension $SlotTextCopyWith on SlotText {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSlotText.copyWith(...)` or `instanceOfSlotText.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SlotTextCWProxy get copyWith => _$SlotTextCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SlotText _$SlotTextFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SlotText', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['slot', 'messageKey', 'variant', 'text', 'reactable'],
  );
  final val = SlotText(
    slot: $checkedConvert('slot', (v) => v as String),
    messageKey: $checkedConvert('messageKey', (v) => v as String),
    variant: $checkedConvert(
      'variant',
      (v) => $enumDecode(_$SlotTextVariantEnumEnumMap, v),
    ),
    text: $checkedConvert(
      'text',
      (v) => RenderedText.fromJson(v as Map<String, dynamic>),
    ),
    reactable: $checkedConvert('reactable', (v) => v as bool),
    reaction: $checkedConvert(
      'reaction',
      (v) => $enumDecodeNullable(_$SlotTextReactionEnumEnumMap, v),
    ),
    todayReason: $checkedConvert(
      'todayReason',
      (v) =>
          v == null ? null : RenderedText.fromJson(v as Map<String, dynamic>),
    ),
    evidence: $checkedConvert(
      'evidence',
      (v) => (v as List<dynamic>?)
          ?.map((e) => Evidence.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$SlotTextToJson(SlotText instance) => <String, dynamic>{
  'slot': instance.slot,
  'messageKey': instance.messageKey,
  'variant': _$SlotTextVariantEnumEnumMap[instance.variant]!,
  'text': instance.text.toJson(),
  'reactable': instance.reactable,
  'reaction': ?_$SlotTextReactionEnumEnumMap[instance.reaction],
  'todayReason': ?instance.todayReason?.toJson(),
  'evidence': ?instance.evidence?.map((e) => e.toJson()).toList(),
};

const _$SlotTextVariantEnumEnumMap = {
  SlotTextVariantEnum.advice: 'advice',
  SlotTextVariantEnum.state: 'state',
  SlotTextVariantEnum.care: 'care',
  SlotTextVariantEnum.n1: '1',
  SlotTextVariantEnum.n2: '2',
  SlotTextVariantEnum.single: 'single',
};

const _$SlotTextReactionEnumEnumMap = {SlotTextReactionEnum.like: 'like'};
