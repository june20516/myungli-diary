// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seun_year.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SeunYearCWProxy {
  SeunYear year(int year);

  SeunYear pillar(Pillar pillar);

  SeunYear tenGod(TenGod tenGod);

  SeunYear relationsWithNatal(List<RelationKind> relationsWithNatal);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SeunYear(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SeunYear(...).copyWith(id: 12, name: "My name")
  /// ```
  SeunYear call({
    int year,
    Pillar pillar,
    TenGod tenGod,
    List<RelationKind> relationsWithNatal,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSeunYear.copyWith(...)` or call `instanceOfSeunYear.copyWith.fieldName(value)` for a single field.
class _$SeunYearCWProxyImpl implements _$SeunYearCWProxy {
  const _$SeunYearCWProxyImpl(this._value);

  final SeunYear _value;

  @override
  SeunYear year(int year) => call(year: year);

  @override
  SeunYear pillar(Pillar pillar) => call(pillar: pillar);

  @override
  SeunYear tenGod(TenGod tenGod) => call(tenGod: tenGod);

  @override
  SeunYear relationsWithNatal(List<RelationKind> relationsWithNatal) =>
      call(relationsWithNatal: relationsWithNatal);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SeunYear(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SeunYear(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SeunYear call({
    Object? year = const $CopyWithPlaceholder(),
    Object? pillar = const $CopyWithPlaceholder(),
    Object? tenGod = const $CopyWithPlaceholder(),
    Object? relationsWithNatal = const $CopyWithPlaceholder(),
  }) {
    return SeunYear(
      year: year == const $CopyWithPlaceholder() || year == null
          ? _value.year
          // ignore: cast_nullable_to_non_nullable
          : year as int,
      pillar: pillar == const $CopyWithPlaceholder() || pillar == null
          ? _value.pillar
          // ignore: cast_nullable_to_non_nullable
          : pillar as Pillar,
      tenGod: tenGod == const $CopyWithPlaceholder() || tenGod == null
          ? _value.tenGod
          // ignore: cast_nullable_to_non_nullable
          : tenGod as TenGod,
      relationsWithNatal:
          relationsWithNatal == const $CopyWithPlaceholder() ||
              relationsWithNatal == null
          ? _value.relationsWithNatal
          // ignore: cast_nullable_to_non_nullable
          : relationsWithNatal as List<RelationKind>,
    );
  }
}

extension $SeunYearCopyWith on SeunYear {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSeunYear.copyWith(...)` or `instanceOfSeunYear.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SeunYearCWProxy get copyWith => _$SeunYearCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SeunYear _$SeunYearFromJson(Map<String, dynamic> json) => $checkedCreate(
  'SeunYear',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['year', 'pillar', 'tenGod', 'relationsWithNatal'],
    );
    final val = SeunYear(
      year: $checkedConvert('year', (v) => (v as num).toInt()),
      pillar: $checkedConvert(
        'pillar',
        (v) => Pillar.fromJson(v as Map<String, dynamic>),
      ),
      tenGod: $checkedConvert('tenGod', (v) => $enumDecode(_$TenGodEnumMap, v)),
      relationsWithNatal: $checkedConvert(
        'relationsWithNatal',
        (v) => (v as List<dynamic>)
            .map((e) => $enumDecode(_$RelationKindEnumMap, e))
            .toList(),
      ),
    );
    return val;
  },
);

Map<String, dynamic> _$SeunYearToJson(SeunYear instance) => <String, dynamic>{
  'year': instance.year,
  'pillar': instance.pillar.toJson(),
  'tenGod': _$TenGodEnumMap[instance.tenGod]!,
  'relationsWithNatal': instance.relationsWithNatal
      .map((e) => _$RelationKindEnumMap[e]!)
      .toList(),
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

const _$RelationKindEnumMap = {
  RelationKind.stemHap: 'stem_hap',
  RelationKind.branchHap: 'branch_hap',
  RelationKind.chung: 'chung',
  RelationKind.hyeong: 'hyeong',
};
