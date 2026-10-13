// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solar_term.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SolarTermCWProxy {
  SolarTerm kind(SolarTermKind kind);

  SolarTerm at(DateTime at);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SolarTerm(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SolarTerm(...).copyWith(id: 12, name: "My name")
  /// ```
  SolarTerm call({SolarTermKind kind, DateTime at});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSolarTerm.copyWith(...)` or call `instanceOfSolarTerm.copyWith.fieldName(value)` for a single field.
class _$SolarTermCWProxyImpl implements _$SolarTermCWProxy {
  const _$SolarTermCWProxyImpl(this._value);

  final SolarTerm _value;

  @override
  SolarTerm kind(SolarTermKind kind) => call(kind: kind);

  @override
  SolarTerm at(DateTime at) => call(at: at);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SolarTerm(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SolarTerm(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SolarTerm call({
    Object? kind = const $CopyWithPlaceholder(),
    Object? at = const $CopyWithPlaceholder(),
  }) {
    return SolarTerm(
      kind: kind == const $CopyWithPlaceholder() || kind == null
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as SolarTermKind,
      at: at == const $CopyWithPlaceholder() || at == null
          ? _value.at
          // ignore: cast_nullable_to_non_nullable
          : at as DateTime,
    );
  }
}

extension $SolarTermCopyWith on SolarTerm {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSolarTerm.copyWith(...)` or `instanceOfSolarTerm.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SolarTermCWProxy get copyWith => _$SolarTermCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SolarTerm _$SolarTermFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SolarTerm', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['kind', 'at']);
      final val = SolarTerm(
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(_$SolarTermKindEnumMap, v),
        ),
        at: $checkedConvert('at', (v) => DateTime.parse(v as String)),
      );
      return val;
    });

Map<String, dynamic> _$SolarTermToJson(SolarTerm instance) => <String, dynamic>{
  'kind': _$SolarTermKindEnumMap[instance.kind]!,
  'at': instance.at.toIso8601String(),
};

const _$SolarTermKindEnumMap = {
  SolarTermKind.sohan: 'sohan',
  SolarTermKind.daehan: 'daehan',
  SolarTermKind.ipchun: 'ipchun',
  SolarTermKind.usu: 'usu',
  SolarTermKind.gyeongchip: 'gyeongchip',
  SolarTermKind.chunbun: 'chunbun',
  SolarTermKind.cheongmyeong: 'cheongmyeong',
  SolarTermKind.gogu: 'gogu',
  SolarTermKind.ipha: 'ipha',
  SolarTermKind.soman: 'soman',
  SolarTermKind.mangjong: 'mangjong',
  SolarTermKind.haji: 'haji',
  SolarTermKind.soseo: 'soseo',
  SolarTermKind.daeseo: 'daeseo',
  SolarTermKind.ipchu: 'ipchu',
  SolarTermKind.cheoseo: 'cheoseo',
  SolarTermKind.baengno: 'baengno',
  SolarTermKind.chubun: 'chubun',
  SolarTermKind.hallo: 'hallo',
  SolarTermKind.sanggang: 'sanggang',
  SolarTermKind.ipdong: 'ipdong',
  SolarTermKind.soseol: 'soseol',
  SolarTermKind.daeseol: 'daeseol',
  SolarTermKind.dongji: 'dongji',
};
