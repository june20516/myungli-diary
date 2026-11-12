// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shinsal_at.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ShinsalAtCWProxy {
  ShinsalAt kind(ShinsalKind kind);

  ShinsalAt position(Position position);

  ShinsalAt positions(List<Position> positions);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ShinsalAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ShinsalAt(...).copyWith(id: 12, name: "My name")
  /// ```
  ShinsalAt call({
    ShinsalKind kind,
    Position position,
    List<Position> positions,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfShinsalAt.copyWith(...)` or call `instanceOfShinsalAt.copyWith.fieldName(value)` for a single field.
class _$ShinsalAtCWProxyImpl implements _$ShinsalAtCWProxy {
  const _$ShinsalAtCWProxyImpl(this._value);

  final ShinsalAt _value;

  @override
  ShinsalAt kind(ShinsalKind kind) => call(kind: kind);

  @override
  ShinsalAt position(Position position) => call(position: position);

  @override
  ShinsalAt positions(List<Position> positions) => call(positions: positions);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ShinsalAt(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ShinsalAt(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ShinsalAt call({
    Object? kind = const $CopyWithPlaceholder(),
    Object? position = const $CopyWithPlaceholder(),
    Object? positions = const $CopyWithPlaceholder(),
  }) {
    return ShinsalAt(
      kind: kind == const $CopyWithPlaceholder() || kind == null
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as ShinsalKind,
      position: position == const $CopyWithPlaceholder() || position == null
          ? _value.position
          // ignore: cast_nullable_to_non_nullable
          : position as Position,
      positions: positions == const $CopyWithPlaceholder() || positions == null
          ? _value.positions
          // ignore: cast_nullable_to_non_nullable
          : positions as List<Position>,
    );
  }
}

extension $ShinsalAtCopyWith on ShinsalAt {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfShinsalAt.copyWith(...)` or `instanceOfShinsalAt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ShinsalAtCWProxy get copyWith => _$ShinsalAtCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShinsalAt _$ShinsalAtFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ShinsalAt', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['kind', 'position', 'positions']);
      final val = ShinsalAt(
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$ShinsalKindEnumMap,
            v,
            unknownValue: ShinsalKind.unknownDefaultOpenApi,
          ),
        ),
        position: $checkedConvert(
          'position',
          (v) => $enumDecode(_$PositionEnumMap, v),
        ),
        positions: $checkedConvert(
          'positions',
          (v) => (v as List<dynamic>)
              .map((e) => $enumDecode(_$PositionEnumMap, e))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ShinsalAtToJson(ShinsalAt instance) => <String, dynamic>{
  'kind': _$ShinsalKindEnumMap[instance.kind]!,
  'position': _$PositionEnumMap[instance.position]!,
  'positions': instance.positions.map((e) => _$PositionEnumMap[e]!).toList(),
};

const _$ShinsalKindEnumMap = {
  ShinsalKind.cheoneulGwiin: 'cheoneul_gwiin',
  ShinsalKind.dohwa: 'dohwa',
  ShinsalKind.yeokma: 'yeokma',
  ShinsalKind.hwagae: 'hwagae',
  ShinsalKind.yangin: 'yangin',
  ShinsalKind.gongmang: 'gongmang',
  ShinsalKind.cheondeok: 'cheondeok',
  ShinsalKind.woldeok: 'woldeok',
  ShinsalKind.geumyeo: 'geumyeo',
  ShinsalKind.gosin: 'gosin',
  ShinsalKind.gwasuk: 'gwasuk',
  ShinsalKind.wonjin: 'wonjin',
  ShinsalKind.gugyo: 'gugyo',
  ShinsalKind.cheonraJimang: 'cheonra_jimang',
  ShinsalKind.goegang: 'goegang',
  ShinsalKind.sipakDaepae: 'sipak_daepae',
  ShinsalKind.eumchakYangcha: 'eumchak_yangcha',
  ShinsalKind.samgi: 'samgi',
  ShinsalKind.amrok: 'amrok',
  ShinsalKind.unknownDefaultOpenApi: 'unknown_default_open_api',
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
