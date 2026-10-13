// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ten_god_at.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TenGodAtCWProxy {
  TenGodAt position(Position position);

  TenGodAt tenGod(TenGod tenGod);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TenGodAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TenGodAt(...).copyWith(id: 12, name: "My name")
  /// ```
  TenGodAt call({Position position, TenGod tenGod});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTenGodAt.copyWith(...)` or call `instanceOfTenGodAt.copyWith.fieldName(value)` for a single field.
class _$TenGodAtCWProxyImpl implements _$TenGodAtCWProxy {
  const _$TenGodAtCWProxyImpl(this._value);

  final TenGodAt _value;

  @override
  TenGodAt position(Position position) => call(position: position);

  @override
  TenGodAt tenGod(TenGod tenGod) => call(tenGod: tenGod);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TenGodAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TenGodAt(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TenGodAt call({
    Object? position = const $CopyWithPlaceholder(),
    Object? tenGod = const $CopyWithPlaceholder(),
  }) {
    return TenGodAt(
      position: position == const $CopyWithPlaceholder() || position == null
          ? _value.position
          // ignore: cast_nullable_to_non_nullable
          : position as Position,
      tenGod: tenGod == const $CopyWithPlaceholder() || tenGod == null
          ? _value.tenGod
          // ignore: cast_nullable_to_non_nullable
          : tenGod as TenGod,
    );
  }
}

extension $TenGodAtCopyWith on TenGodAt {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTenGodAt.copyWith(...)` or `instanceOfTenGodAt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TenGodAtCWProxy get copyWith => _$TenGodAtCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TenGodAt _$TenGodAtFromJson(Map<String, dynamic> json) => $checkedCreate(
  'TenGodAt',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['position', 'tenGod']);
    final val = TenGodAt(
      position: $checkedConvert(
        'position',
        (v) => $enumDecode(_$PositionEnumMap, v),
      ),
      tenGod: $checkedConvert('tenGod', (v) => $enumDecode(_$TenGodEnumMap, v)),
    );
    return val;
  },
);

Map<String, dynamic> _$TenGodAtToJson(TenGodAt instance) => <String, dynamic>{
  'position': _$PositionEnumMap[instance.position]!,
  'tenGod': _$TenGodEnumMap[instance.tenGod]!,
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

const _$TenGodEnumMap = {
  TenGod.bigyeon: 'bigyeon',
  TenGod.geopjae: 'geopjae',
  TenGod.siksin: 'siksin',
  TenGod.sanggwan: 'sanggwan',
  TenGod.pyeonjae: 'pyeonjae',
  TenGod.jeongjae: 'jeongjae',
  TenGod.pyeongwan: 'pyeongwan',
  TenGod.jeonggwan: 'jeonggwan',
  TenGod.pyeonin: 'pyeonin',
  TenGod.jeongin: 'jeongin',
};
