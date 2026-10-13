// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'twelve_stage_at.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TwelveStageAtCWProxy {
  TwelveStageAt position(Position position);

  TwelveStageAt stage(TwelveStage stage);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TwelveStageAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TwelveStageAt(...).copyWith(id: 12, name: "My name")
  /// ```
  TwelveStageAt call({Position position, TwelveStage stage});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTwelveStageAt.copyWith(...)` or call `instanceOfTwelveStageAt.copyWith.fieldName(value)` for a single field.
class _$TwelveStageAtCWProxyImpl implements _$TwelveStageAtCWProxy {
  const _$TwelveStageAtCWProxyImpl(this._value);

  final TwelveStageAt _value;

  @override
  TwelveStageAt position(Position position) => call(position: position);

  @override
  TwelveStageAt stage(TwelveStage stage) => call(stage: stage);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TwelveStageAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TwelveStageAt(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TwelveStageAt call({
    Object? position = const $CopyWithPlaceholder(),
    Object? stage = const $CopyWithPlaceholder(),
  }) {
    return TwelveStageAt(
      position: position == const $CopyWithPlaceholder() || position == null
          ? _value.position
          // ignore: cast_nullable_to_non_nullable
          : position as Position,
      stage: stage == const $CopyWithPlaceholder() || stage == null
          ? _value.stage
          // ignore: cast_nullable_to_non_nullable
          : stage as TwelveStage,
    );
  }
}

extension $TwelveStageAtCopyWith on TwelveStageAt {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTwelveStageAt.copyWith(...)` or `instanceOfTwelveStageAt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TwelveStageAtCWProxy get copyWith => _$TwelveStageAtCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TwelveStageAt _$TwelveStageAtFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TwelveStageAt', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['position', 'stage']);
      final val = TwelveStageAt(
        position: $checkedConvert(
          'position',
          (v) => $enumDecode(_$PositionEnumMap, v),
        ),
        stage: $checkedConvert(
          'stage',
          (v) => $enumDecode(_$TwelveStageEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TwelveStageAtToJson(TwelveStageAt instance) =>
    <String, dynamic>{
      'position': _$PositionEnumMap[instance.position]!,
      'stage': _$TwelveStageEnumMap[instance.stage]!,
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

const _$TwelveStageEnumMap = {
  TwelveStage.jangsaeng: 'jangsaeng',
  TwelveStage.mokyok: 'mokyok',
  TwelveStage.gwandae: 'gwandae',
  TwelveStage.geonrok: 'geonrok',
  TwelveStage.jewang: 'jewang',
  TwelveStage.soe: 'soe',
  TwelveStage.byeong: 'byeong',
  TwelveStage.sa: 'sa',
  TwelveStage.myo: 'myo',
  TwelveStage.jeol: 'jeol',
  TwelveStage.tae: 'tae',
  TwelveStage.yang: 'yang',
};
