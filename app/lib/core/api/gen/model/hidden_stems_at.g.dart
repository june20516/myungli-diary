// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hidden_stems_at.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HiddenStemsAtCWProxy {
  HiddenStemsAt position(Position position);

  HiddenStemsAt stems(List<HiddenStem> stems);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HiddenStemsAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HiddenStemsAt(...).copyWith(id: 12, name: "My name")
  /// ```
  HiddenStemsAt call({Position position, List<HiddenStem> stems});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfHiddenStemsAt.copyWith(...)` or call `instanceOfHiddenStemsAt.copyWith.fieldName(value)` for a single field.
class _$HiddenStemsAtCWProxyImpl implements _$HiddenStemsAtCWProxy {
  const _$HiddenStemsAtCWProxyImpl(this._value);

  final HiddenStemsAt _value;

  @override
  HiddenStemsAt position(Position position) => call(position: position);

  @override
  HiddenStemsAt stems(List<HiddenStem> stems) => call(stems: stems);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HiddenStemsAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HiddenStemsAt(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  HiddenStemsAt call({
    Object? position = const $CopyWithPlaceholder(),
    Object? stems = const $CopyWithPlaceholder(),
  }) {
    return HiddenStemsAt(
      position: position == const $CopyWithPlaceholder() || position == null
          ? _value.position
          // ignore: cast_nullable_to_non_nullable
          : position as Position,
      stems: stems == const $CopyWithPlaceholder() || stems == null
          ? _value.stems
          // ignore: cast_nullable_to_non_nullable
          : stems as List<HiddenStem>,
    );
  }
}

extension $HiddenStemsAtCopyWith on HiddenStemsAt {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfHiddenStemsAt.copyWith(...)` or `instanceOfHiddenStemsAt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HiddenStemsAtCWProxy get copyWith => _$HiddenStemsAtCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiddenStemsAt _$HiddenStemsAtFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HiddenStemsAt', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['position', 'stems']);
      final val = HiddenStemsAt(
        position: $checkedConvert(
          'position',
          (v) => $enumDecode(_$PositionEnumMap, v),
        ),
        stems: $checkedConvert(
          'stems',
          (v) => (v as List<dynamic>)
              .map((e) => HiddenStem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HiddenStemsAtToJson(HiddenStemsAt instance) =>
    <String, dynamic>{
      'position': _$PositionEnumMap[instance.position]!,
      'stems': instance.stems.map((e) => e.toJson()).toList(),
    };

const _$PositionEnumMap = {
  Position.yearStem: 'year_stem',
  Position.yearBranch: 'year_branch',
  Position.monthStem: 'month_stem',
  Position.monthBranch: 'month_branch',
  Position.dayStem: 'day_stem',
  Position.dayBranch: 'day_branch',
  Position.hourStem: 'hour_stem',
  Position.hourBranch: 'hour_branch',
};
