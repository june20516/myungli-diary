// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reaction_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReactionInputCWProxy {
  ReactionInput reaction(ReactionInputReactionEnum reaction);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ReactionInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ReactionInput(...).copyWith(id: 12, name: "My name")
  /// ```
  ReactionInput call({ReactionInputReactionEnum reaction});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfReactionInput.copyWith(...)` or call `instanceOfReactionInput.copyWith.fieldName(value)` for a single field.
class _$ReactionInputCWProxyImpl implements _$ReactionInputCWProxy {
  const _$ReactionInputCWProxyImpl(this._value);

  final ReactionInput _value;

  @override
  ReactionInput reaction(ReactionInputReactionEnum reaction) =>
      call(reaction: reaction);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ReactionInput(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ReactionInput(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ReactionInput call({Object? reaction = const $CopyWithPlaceholder()}) {
    return ReactionInput(
      reaction: reaction == const $CopyWithPlaceholder() || reaction == null
          ? _value.reaction
          // ignore: cast_nullable_to_non_nullable
          : reaction as ReactionInputReactionEnum,
    );
  }
}

extension $ReactionInputCopyWith on ReactionInput {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfReactionInput.copyWith(...)` or `instanceOfReactionInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReactionInputCWProxy get copyWith => _$ReactionInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReactionInput _$ReactionInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReactionInput', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['reaction']);
      final val = ReactionInput(
        reaction: $checkedConvert(
          'reaction',
          (v) => $enumDecode(_$ReactionInputReactionEnumEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ReactionInputToJson(ReactionInput instance) =>
    <String, dynamic>{
      'reaction': _$ReactionInputReactionEnumEnumMap[instance.reaction]!,
    };

const _$ReactionInputReactionEnumEnumMap = {
  ReactionInputReactionEnum.like: 'like',
};
