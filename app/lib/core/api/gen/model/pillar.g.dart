// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pillar.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PillarCWProxy {
  Pillar stem(Stem stem);

  Pillar branch(Branch branch);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Pillar(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Pillar(...).copyWith(id: 12, name: "My name")
  /// ```
  Pillar call({Stem stem, Branch branch});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPillar.copyWith(...)` or call `instanceOfPillar.copyWith.fieldName(value)` for a single field.
class _$PillarCWProxyImpl implements _$PillarCWProxy {
  const _$PillarCWProxyImpl(this._value);

  final Pillar _value;

  @override
  Pillar stem(Stem stem) => call(stem: stem);

  @override
  Pillar branch(Branch branch) => call(branch: branch);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Pillar(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Pillar(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Pillar call({
    Object? stem = const $CopyWithPlaceholder(),
    Object? branch = const $CopyWithPlaceholder(),
  }) {
    return Pillar(
      stem: stem == const $CopyWithPlaceholder() || stem == null
          ? _value.stem
          // ignore: cast_nullable_to_non_nullable
          : stem as Stem,
      branch: branch == const $CopyWithPlaceholder() || branch == null
          ? _value.branch
          // ignore: cast_nullable_to_non_nullable
          : branch as Branch,
    );
  }
}

extension $PillarCopyWith on Pillar {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPillar.copyWith(...)` or `instanceOfPillar.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PillarCWProxy get copyWith => _$PillarCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pillar _$PillarFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Pillar',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['stem', 'branch']);
    final val = Pillar(
      stem: $checkedConvert('stem', (v) => $enumDecode(_$StemEnumMap, v)),
      branch: $checkedConvert('branch', (v) => $enumDecode(_$BranchEnumMap, v)),
    );
    return val;
  },
);

Map<String, dynamic> _$PillarToJson(Pillar instance) => <String, dynamic>{
  'stem': _$StemEnumMap[instance.stem]!,
  'branch': _$BranchEnumMap[instance.branch]!,
};

const _$StemEnumMap = {
  Stem.gap: 'gap',
  Stem.eul: 'eul',
  Stem.byeong: 'byeong',
  Stem.jeong: 'jeong',
  Stem.mu: 'mu',
  Stem.gi: 'gi',
  Stem.gyeong: 'gyeong',
  Stem.sin: 'sin',
  Stem.im: 'im',
  Stem.gye: 'gye',
};

const _$BranchEnumMap = {
  Branch.ja: 'ja',
  Branch.chuk: 'chuk',
  Branch.in_: 'in',
  Branch.myo: 'myo',
  Branch.jin: 'jin',
  Branch.sa: 'sa',
  Branch.o: 'o',
  Branch.mi: 'mi',
  Branch.shin: 'shin',
  Branch.yu: 'yu',
  Branch.sul: 'sul',
  Branch.hae: 'hae',
};
