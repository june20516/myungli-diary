// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_choice.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GuideChoiceCWProxy {
  GuideChoice messageKey(String messageKey);

  GuideChoice variant(String variant);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GuideChoice(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GuideChoice(...).copyWith(id: 12, name: "My name")
  /// ```
  GuideChoice call({String messageKey, String variant});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGuideChoice.copyWith(...)` or call `instanceOfGuideChoice.copyWith.fieldName(value)` for a single field.
class _$GuideChoiceCWProxyImpl implements _$GuideChoiceCWProxy {
  const _$GuideChoiceCWProxyImpl(this._value);

  final GuideChoice _value;

  @override
  GuideChoice messageKey(String messageKey) => call(messageKey: messageKey);

  @override
  GuideChoice variant(String variant) => call(variant: variant);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GuideChoice(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GuideChoice(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GuideChoice call({
    Object? messageKey = const $CopyWithPlaceholder(),
    Object? variant = const $CopyWithPlaceholder(),
  }) {
    return GuideChoice(
      messageKey:
          messageKey == const $CopyWithPlaceholder() || messageKey == null
          ? _value.messageKey
          // ignore: cast_nullable_to_non_nullable
          : messageKey as String,
      variant: variant == const $CopyWithPlaceholder() || variant == null
          ? _value.variant
          // ignore: cast_nullable_to_non_nullable
          : variant as String,
    );
  }
}

extension $GuideChoiceCopyWith on GuideChoice {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGuideChoice.copyWith(...)` or `instanceOfGuideChoice.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GuideChoiceCWProxy get copyWith => _$GuideChoiceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GuideChoice _$GuideChoiceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GuideChoice', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['messageKey', 'variant']);
      final val = GuideChoice(
        messageKey: $checkedConvert('messageKey', (v) => v as String),
        variant: $checkedConvert('variant', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$GuideChoiceToJson(GuideChoice instance) =>
    <String, dynamic>{
      'messageKey': instance.messageKey,
      'variant': instance.variant,
    };
