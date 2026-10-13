// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hidden_stem.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HiddenStemCWProxy {
  HiddenStem stem(Stem stem);

  HiddenStem tenGod(TenGod tenGod);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HiddenStem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HiddenStem(...).copyWith(id: 12, name: "My name")
  /// ```
  HiddenStem call({Stem stem, TenGod tenGod});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfHiddenStem.copyWith(...)` or call `instanceOfHiddenStem.copyWith.fieldName(value)` for a single field.
class _$HiddenStemCWProxyImpl implements _$HiddenStemCWProxy {
  const _$HiddenStemCWProxyImpl(this._value);

  final HiddenStem _value;

  @override
  HiddenStem stem(Stem stem) => call(stem: stem);

  @override
  HiddenStem tenGod(TenGod tenGod) => call(tenGod: tenGod);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HiddenStem(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HiddenStem(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  HiddenStem call({
    Object? stem = const $CopyWithPlaceholder(),
    Object? tenGod = const $CopyWithPlaceholder(),
  }) {
    return HiddenStem(
      stem: stem == const $CopyWithPlaceholder() || stem == null
          ? _value.stem
          // ignore: cast_nullable_to_non_nullable
          : stem as Stem,
      tenGod: tenGod == const $CopyWithPlaceholder() || tenGod == null
          ? _value.tenGod
          // ignore: cast_nullable_to_non_nullable
          : tenGod as TenGod,
    );
  }
}

extension $HiddenStemCopyWith on HiddenStem {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfHiddenStem.copyWith(...)` or `instanceOfHiddenStem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HiddenStemCWProxy get copyWith => _$HiddenStemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiddenStem _$HiddenStemFromJson(Map<String, dynamic> json) => $checkedCreate(
  'HiddenStem',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['stem', 'tenGod']);
    final val = HiddenStem(
      stem: $checkedConvert('stem', (v) => $enumDecode(_$StemEnumMap, v)),
      tenGod: $checkedConvert('tenGod', (v) => $enumDecode(_$TenGodEnumMap, v)),
    );
    return val;
  },
);

Map<String, dynamic> _$HiddenStemToJson(HiddenStem instance) =>
    <String, dynamic>{
      'stem': _$StemEnumMap[instance.stem]!,
      'tenGod': _$TenGodEnumMap[instance.tenGod]!,
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
