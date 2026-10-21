// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daeun_period.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DaeunPeriodCWProxy {
  DaeunPeriod pillar(Pillar pillar);

  DaeunPeriod startAge(int startAge);

  DaeunPeriod startAgeKorean(int startAgeKorean);

  DaeunPeriod startYear(int startYear);

  DaeunPeriod stemTenGod(TenGod stemTenGod);

  DaeunPeriod branchTenGod(TenGod branchTenGod);

  DaeunPeriod twelveStage(TwelveStage twelveStage);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DaeunPeriod(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DaeunPeriod(...).copyWith(id: 12, name: "My name")
  /// ```
  DaeunPeriod call({
    Pillar pillar,
    int startAge,
    int startAgeKorean,
    int startYear,
    TenGod stemTenGod,
    TenGod branchTenGod,
    TwelveStage twelveStage,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDaeunPeriod.copyWith(...)` or call `instanceOfDaeunPeriod.copyWith.fieldName(value)` for a single field.
class _$DaeunPeriodCWProxyImpl implements _$DaeunPeriodCWProxy {
  const _$DaeunPeriodCWProxyImpl(this._value);

  final DaeunPeriod _value;

  @override
  DaeunPeriod pillar(Pillar pillar) => call(pillar: pillar);

  @override
  DaeunPeriod startAge(int startAge) => call(startAge: startAge);

  @override
  DaeunPeriod startAgeKorean(int startAgeKorean) =>
      call(startAgeKorean: startAgeKorean);

  @override
  DaeunPeriod startYear(int startYear) => call(startYear: startYear);

  @override
  DaeunPeriod stemTenGod(TenGod stemTenGod) => call(stemTenGod: stemTenGod);

  @override
  DaeunPeriod branchTenGod(TenGod branchTenGod) =>
      call(branchTenGod: branchTenGod);

  @override
  DaeunPeriod twelveStage(TwelveStage twelveStage) =>
      call(twelveStage: twelveStage);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DaeunPeriod(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DaeunPeriod(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DaeunPeriod call({
    Object? pillar = const $CopyWithPlaceholder(),
    Object? startAge = const $CopyWithPlaceholder(),
    Object? startAgeKorean = const $CopyWithPlaceholder(),
    Object? startYear = const $CopyWithPlaceholder(),
    Object? stemTenGod = const $CopyWithPlaceholder(),
    Object? branchTenGod = const $CopyWithPlaceholder(),
    Object? twelveStage = const $CopyWithPlaceholder(),
  }) {
    return DaeunPeriod(
      pillar: pillar == const $CopyWithPlaceholder() || pillar == null
          ? _value.pillar
          // ignore: cast_nullable_to_non_nullable
          : pillar as Pillar,
      startAge: startAge == const $CopyWithPlaceholder() || startAge == null
          ? _value.startAge
          // ignore: cast_nullable_to_non_nullable
          : startAge as int,
      startAgeKorean:
          startAgeKorean == const $CopyWithPlaceholder() ||
              startAgeKorean == null
          ? _value.startAgeKorean
          // ignore: cast_nullable_to_non_nullable
          : startAgeKorean as int,
      startYear: startYear == const $CopyWithPlaceholder() || startYear == null
          ? _value.startYear
          // ignore: cast_nullable_to_non_nullable
          : startYear as int,
      stemTenGod:
          stemTenGod == const $CopyWithPlaceholder() || stemTenGod == null
          ? _value.stemTenGod
          // ignore: cast_nullable_to_non_nullable
          : stemTenGod as TenGod,
      branchTenGod:
          branchTenGod == const $CopyWithPlaceholder() || branchTenGod == null
          ? _value.branchTenGod
          // ignore: cast_nullable_to_non_nullable
          : branchTenGod as TenGod,
      twelveStage:
          twelveStage == const $CopyWithPlaceholder() || twelveStage == null
          ? _value.twelveStage
          // ignore: cast_nullable_to_non_nullable
          : twelveStage as TwelveStage,
    );
  }
}

extension $DaeunPeriodCopyWith on DaeunPeriod {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDaeunPeriod.copyWith(...)` or `instanceOfDaeunPeriod.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DaeunPeriodCWProxy get copyWith => _$DaeunPeriodCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DaeunPeriod _$DaeunPeriodFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DaeunPeriod', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'pillar',
          'startAge',
          'startAgeKorean',
          'startYear',
          'stemTenGod',
          'branchTenGod',
          'twelveStage',
        ],
      );
      final val = DaeunPeriod(
        pillar: $checkedConvert(
          'pillar',
          (v) => Pillar.fromJson(v as Map<String, dynamic>),
        ),
        startAge: $checkedConvert('startAge', (v) => (v as num).toInt()),
        startAgeKorean: $checkedConvert(
          'startAgeKorean',
          (v) => (v as num).toInt(),
        ),
        startYear: $checkedConvert('startYear', (v) => (v as num).toInt()),
        stemTenGod: $checkedConvert(
          'stemTenGod',
          (v) => $enumDecode(_$TenGodEnumMap, v),
        ),
        branchTenGod: $checkedConvert(
          'branchTenGod',
          (v) => $enumDecode(_$TenGodEnumMap, v),
        ),
        twelveStage: $checkedConvert(
          'twelveStage',
          (v) => $enumDecode(_$TwelveStageEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DaeunPeriodToJson(DaeunPeriod instance) =>
    <String, dynamic>{
      'pillar': instance.pillar.toJson(),
      'startAge': instance.startAge,
      'startAgeKorean': instance.startAgeKorean,
      'startYear': instance.startYear,
      'stemTenGod': _$TenGodEnumMap[instance.stemTenGod]!,
      'branchTenGod': _$TenGodEnumMap[instance.branchTenGod]!,
      'twelveStage': _$TwelveStageEnumMap[instance.twelveStage]!,
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
