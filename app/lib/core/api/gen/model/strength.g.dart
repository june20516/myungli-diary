// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strength.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StrengthCWProxy {
  Strength score(num score);

  Strength level(StrengthLevel level);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Strength(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Strength(...).copyWith(id: 12, name: "My name")
  /// ```
  Strength call({num score, StrengthLevel level});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfStrength.copyWith(...)` or call `instanceOfStrength.copyWith.fieldName(value)` for a single field.
class _$StrengthCWProxyImpl implements _$StrengthCWProxy {
  const _$StrengthCWProxyImpl(this._value);

  final Strength _value;

  @override
  Strength score(num score) => call(score: score);

  @override
  Strength level(StrengthLevel level) => call(level: level);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Strength(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Strength(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Strength call({
    Object? score = const $CopyWithPlaceholder(),
    Object? level = const $CopyWithPlaceholder(),
  }) {
    return Strength(
      score: score == const $CopyWithPlaceholder() || score == null
          ? _value.score
          // ignore: cast_nullable_to_non_nullable
          : score as num,
      level: level == const $CopyWithPlaceholder() || level == null
          ? _value.level
          // ignore: cast_nullable_to_non_nullable
          : level as StrengthLevel,
    );
  }
}

extension $StrengthCopyWith on Strength {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfStrength.copyWith(...)` or `instanceOfStrength.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StrengthCWProxy get copyWith => _$StrengthCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Strength _$StrengthFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Strength', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['score', 'level']);
      final val = Strength(
        score: $checkedConvert('score', (v) => v as num),
        level: $checkedConvert(
          'level',
          (v) => $enumDecode(_$StrengthLevelEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$StrengthToJson(Strength instance) => <String, dynamic>{
  'score': instance.score,
  'level': _$StrengthLevelEnumMap[instance.level]!,
};

const _$StrengthLevelEnumMap = {
  StrengthLevel.veryWeak: 'very_weak',
  StrengthLevel.weak: 'weak',
  StrengthLevel.neutral: 'neutral',
  StrengthLevel.strong: 'strong',
  StrengthLevel.veryStrong: 'very_strong',
};
