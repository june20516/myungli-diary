// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yongsin.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$YongsinCWProxy {
  Yongsin yongsin(FiveElement yongsin);

  Yongsin huisin(FiveElement huisin);

  Yongsin gisin(FiveElement gisin);

  Yongsin tonggwan(FiveElement tonggwan);

  Yongsin method(YongsinMethod method);

  Yongsin johuStem(Stem? johuStem);

  Yongsin basis(SlotText? basis);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Yongsin(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Yongsin(...).copyWith(id: 12, name: "My name")
  /// ```
  Yongsin call({
    FiveElement yongsin,
    FiveElement huisin,
    FiveElement gisin,
    FiveElement tonggwan,
    YongsinMethod method,
    Stem? johuStem,
    SlotText? basis,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfYongsin.copyWith(...)` or call `instanceOfYongsin.copyWith.fieldName(value)` for a single field.
class _$YongsinCWProxyImpl implements _$YongsinCWProxy {
  const _$YongsinCWProxyImpl(this._value);

  final Yongsin _value;

  @override
  Yongsin yongsin(FiveElement yongsin) => call(yongsin: yongsin);

  @override
  Yongsin huisin(FiveElement huisin) => call(huisin: huisin);

  @override
  Yongsin gisin(FiveElement gisin) => call(gisin: gisin);

  @override
  Yongsin tonggwan(FiveElement tonggwan) => call(tonggwan: tonggwan);

  @override
  Yongsin method(YongsinMethod method) => call(method: method);

  @override
  Yongsin johuStem(Stem? johuStem) => call(johuStem: johuStem);

  @override
  Yongsin basis(SlotText? basis) => call(basis: basis);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Yongsin(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Yongsin(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Yongsin call({
    Object? yongsin = const $CopyWithPlaceholder(),
    Object? huisin = const $CopyWithPlaceholder(),
    Object? gisin = const $CopyWithPlaceholder(),
    Object? tonggwan = const $CopyWithPlaceholder(),
    Object? method = const $CopyWithPlaceholder(),
    Object? johuStem = const $CopyWithPlaceholder(),
    Object? basis = const $CopyWithPlaceholder(),
  }) {
    return Yongsin(
      yongsin: yongsin == const $CopyWithPlaceholder() || yongsin == null
          ? _value.yongsin
          // ignore: cast_nullable_to_non_nullable
          : yongsin as FiveElement,
      huisin: huisin == const $CopyWithPlaceholder() || huisin == null
          ? _value.huisin
          // ignore: cast_nullable_to_non_nullable
          : huisin as FiveElement,
      gisin: gisin == const $CopyWithPlaceholder() || gisin == null
          ? _value.gisin
          // ignore: cast_nullable_to_non_nullable
          : gisin as FiveElement,
      tonggwan: tonggwan == const $CopyWithPlaceholder() || tonggwan == null
          ? _value.tonggwan
          // ignore: cast_nullable_to_non_nullable
          : tonggwan as FiveElement,
      method: method == const $CopyWithPlaceholder() || method == null
          ? _value.method
          // ignore: cast_nullable_to_non_nullable
          : method as YongsinMethod,
      johuStem: johuStem == const $CopyWithPlaceholder()
          ? _value.johuStem
          // ignore: cast_nullable_to_non_nullable
          : johuStem as Stem?,
      basis: basis == const $CopyWithPlaceholder()
          ? _value.basis
          // ignore: cast_nullable_to_non_nullable
          : basis as SlotText?,
    );
  }
}

extension $YongsinCopyWith on Yongsin {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfYongsin.copyWith(...)` or `instanceOfYongsin.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$YongsinCWProxy get copyWith => _$YongsinCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Yongsin _$YongsinFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Yongsin',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['yongsin', 'huisin', 'gisin', 'tonggwan', 'method'],
    );
    final val = Yongsin(
      yongsin: $checkedConvert(
        'yongsin',
        (v) => $enumDecode(_$FiveElementEnumMap, v),
      ),
      huisin: $checkedConvert(
        'huisin',
        (v) => $enumDecode(_$FiveElementEnumMap, v),
      ),
      gisin: $checkedConvert(
        'gisin',
        (v) => $enumDecode(_$FiveElementEnumMap, v),
      ),
      tonggwan: $checkedConvert(
        'tonggwan',
        (v) => $enumDecode(_$FiveElementEnumMap, v),
      ),
      method: $checkedConvert(
        'method',
        (v) => $enumDecode(
          _$YongsinMethodEnumMap,
          v,
          unknownValue: YongsinMethod.unknownDefaultOpenApi,
        ),
      ),
      johuStem: $checkedConvert(
        'johuStem',
        (v) => $enumDecodeNullable(_$StemEnumMap, v),
      ),
      basis: $checkedConvert(
        'basis',
        (v) => v == null ? null : SlotText.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
);

Map<String, dynamic> _$YongsinToJson(Yongsin instance) => <String, dynamic>{
  'yongsin': _$FiveElementEnumMap[instance.yongsin]!,
  'huisin': _$FiveElementEnumMap[instance.huisin]!,
  'gisin': _$FiveElementEnumMap[instance.gisin]!,
  'tonggwan': _$FiveElementEnumMap[instance.tonggwan]!,
  'method': _$YongsinMethodEnumMap[instance.method]!,
  'johuStem': ?_$StemEnumMap[instance.johuStem],
  'basis': ?instance.basis?.toJson(),
};

const _$FiveElementEnumMap = {
  FiveElement.wood: 'wood',
  FiveElement.fire: 'fire',
  FiveElement.earth: 'earth',
  FiveElement.metal: 'metal',
  FiveElement.water: 'water',
};

const _$YongsinMethodEnumMap = {
  YongsinMethod.johu: 'johu',
  YongsinMethod.johuNeutral: 'johu_neutral',
  YongsinMethod.eokbu: 'eokbu',
  YongsinMethod.unknownDefaultOpenApi: 'unknown_default_open_api',
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
