// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relation.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RelationCWProxy {
  Relation kind(RelationKind kind);

  Relation natalPosition(Position natalPosition);

  Relation suppressed(bool suppressed);

  Relation suppressedBy(RelationKind? suppressedBy);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Relation(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Relation(...).copyWith(id: 12, name: "My name")
  /// ```
  Relation call({
    RelationKind kind,
    Position natalPosition,
    bool suppressed,
    RelationKind? suppressedBy,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfRelation.copyWith(...)` or call `instanceOfRelation.copyWith.fieldName(value)` for a single field.
class _$RelationCWProxyImpl implements _$RelationCWProxy {
  const _$RelationCWProxyImpl(this._value);

  final Relation _value;

  @override
  Relation kind(RelationKind kind) => call(kind: kind);

  @override
  Relation natalPosition(Position natalPosition) =>
      call(natalPosition: natalPosition);

  @override
  Relation suppressed(bool suppressed) => call(suppressed: suppressed);

  @override
  Relation suppressedBy(RelationKind? suppressedBy) =>
      call(suppressedBy: suppressedBy);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Relation(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Relation(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Relation call({
    Object? kind = const $CopyWithPlaceholder(),
    Object? natalPosition = const $CopyWithPlaceholder(),
    Object? suppressed = const $CopyWithPlaceholder(),
    Object? suppressedBy = const $CopyWithPlaceholder(),
  }) {
    return Relation(
      kind: kind == const $CopyWithPlaceholder() || kind == null
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as RelationKind,
      natalPosition:
          natalPosition == const $CopyWithPlaceholder() || natalPosition == null
          ? _value.natalPosition
          // ignore: cast_nullable_to_non_nullable
          : natalPosition as Position,
      suppressed:
          suppressed == const $CopyWithPlaceholder() || suppressed == null
          ? _value.suppressed
          // ignore: cast_nullable_to_non_nullable
          : suppressed as bool,
      suppressedBy: suppressedBy == const $CopyWithPlaceholder()
          ? _value.suppressedBy
          // ignore: cast_nullable_to_non_nullable
          : suppressedBy as RelationKind?,
    );
  }
}

extension $RelationCopyWith on Relation {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfRelation.copyWith(...)` or `instanceOfRelation.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RelationCWProxy get copyWith => _$RelationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Relation _$RelationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Relation', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['kind', 'natalPosition', 'suppressed'],
      );
      final val = Relation(
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$RelationKindEnumMap,
            v,
            unknownValue: RelationKind.unknownDefaultOpenApi,
          ),
        ),
        natalPosition: $checkedConvert(
          'natalPosition',
          (v) => $enumDecode(_$PositionEnumMap, v),
        ),
        suppressed: $checkedConvert('suppressed', (v) => v as bool),
        suppressedBy: $checkedConvert(
          'suppressedBy',
          (v) => $enumDecodeNullable(
            _$RelationKindEnumMap,
            v,
            unknownValue: RelationKind.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$RelationToJson(Relation instance) => <String, dynamic>{
  'kind': _$RelationKindEnumMap[instance.kind]!,
  'natalPosition': _$PositionEnumMap[instance.natalPosition]!,
  'suppressed': instance.suppressed,
  'suppressedBy': ?_$RelationKindEnumMap[instance.suppressedBy],
};

const _$RelationKindEnumMap = {
  RelationKind.stemHap: 'stem_hap',
  RelationKind.branchHap: 'branch_hap',
  RelationKind.chung: 'chung',
  RelationKind.hyeong: 'hyeong',
  RelationKind.unknownDefaultOpenApi: 'unknown_default_open_api',
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
