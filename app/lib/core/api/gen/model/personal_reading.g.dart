// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_reading.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PersonalReadingCWProxy {
  PersonalReading kind(PersonalReadingKindEnum kind);

  PersonalReading position(Position? position);

  PersonalReading index(int? index);

  PersonalReading shinsal(ShinsalKind? shinsal);

  PersonalReading text(RenderedText text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PersonalReading(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PersonalReading(...).copyWith(id: 12, name: "My name")
  /// ```
  PersonalReading call({
    PersonalReadingKindEnum kind,
    Position? position,
    int? index,
    ShinsalKind? shinsal,
    RenderedText text,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPersonalReading.copyWith(...)` or call `instanceOfPersonalReading.copyWith.fieldName(value)` for a single field.
class _$PersonalReadingCWProxyImpl implements _$PersonalReadingCWProxy {
  const _$PersonalReadingCWProxyImpl(this._value);

  final PersonalReading _value;

  @override
  PersonalReading kind(PersonalReadingKindEnum kind) => call(kind: kind);

  @override
  PersonalReading position(Position? position) => call(position: position);

  @override
  PersonalReading index(int? index) => call(index: index);

  @override
  PersonalReading shinsal(ShinsalKind? shinsal) => call(shinsal: shinsal);

  @override
  PersonalReading text(RenderedText text) => call(text: text);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PersonalReading(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PersonalReading(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PersonalReading call({
    Object? kind = const $CopyWithPlaceholder(),
    Object? position = const $CopyWithPlaceholder(),
    Object? index = const $CopyWithPlaceholder(),
    Object? shinsal = const $CopyWithPlaceholder(),
    Object? text = const $CopyWithPlaceholder(),
  }) {
    return PersonalReading(
      kind: kind == const $CopyWithPlaceholder() || kind == null
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as PersonalReadingKindEnum,
      position: position == const $CopyWithPlaceholder()
          ? _value.position
          // ignore: cast_nullable_to_non_nullable
          : position as Position?,
      index: index == const $CopyWithPlaceholder()
          ? _value.index
          // ignore: cast_nullable_to_non_nullable
          : index as int?,
      shinsal: shinsal == const $CopyWithPlaceholder()
          ? _value.shinsal
          // ignore: cast_nullable_to_non_nullable
          : shinsal as ShinsalKind?,
      text: text == const $CopyWithPlaceholder() || text == null
          ? _value.text
          // ignore: cast_nullable_to_non_nullable
          : text as RenderedText,
    );
  }
}

extension $PersonalReadingCopyWith on PersonalReading {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPersonalReading.copyWith(...)` or `instanceOfPersonalReading.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PersonalReadingCWProxy get copyWith => _$PersonalReadingCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonalReading _$PersonalReadingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PersonalReading', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['kind', 'text']);
      final val = PersonalReading(
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(_$PersonalReadingKindEnumEnumMap, v),
        ),
        position: $checkedConvert(
          'position',
          (v) => $enumDecodeNullable(_$PositionEnumMap, v),
        ),
        index: $checkedConvert('index', (v) => (v as num?)?.toInt()),
        shinsal: $checkedConvert(
          'shinsal',
          (v) => $enumDecodeNullable(_$ShinsalKindEnumMap, v),
        ),
        text: $checkedConvert(
          'text',
          (v) => RenderedText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PersonalReadingToJson(PersonalReading instance) =>
    <String, dynamic>{
      'kind': _$PersonalReadingKindEnumEnumMap[instance.kind]!,
      'position': ?_$PositionEnumMap[instance.position],
      'index': ?instance.index,
      'shinsal': ?_$ShinsalKindEnumMap[instance.shinsal],
      'text': instance.text.toJson(),
    };

const _$PersonalReadingKindEnumEnumMap = {
  PersonalReadingKindEnum.PersonalReadingKindDayMaster: 'day_master',
  PersonalReadingKindEnum.PersonalReadingKindTenGod: 'ten_god',
  PersonalReadingKindEnum.PersonalReadingKindHiddenTenGod: 'hidden_ten_god',
  PersonalReadingKindEnum.PersonalReadingKindTwelveStage: 'twelve_stage',
  PersonalReadingKindEnum.PersonalReadingKindShinsal: 'shinsal',
  PersonalReadingKindEnum.PersonalReadingKindDaeunStemTenGod:
      'daeun_stem_ten_god',
  PersonalReadingKindEnum.PersonalReadingKindDaeunBranchTenGod:
      'daeun_branch_ten_god',
  PersonalReadingKindEnum.PersonalReadingKindDaeunTwelveStage:
      'daeun_twelve_stage',
  PersonalReadingKindEnum.PersonalReadingKindSeunTenGod: 'seun_ten_god',
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

const _$ShinsalKindEnumMap = {
  ShinsalKind.cheoneulGwiin: 'cheoneul_gwiin',
  ShinsalKind.dohwa: 'dohwa',
  ShinsalKind.yeokma: 'yeokma',
  ShinsalKind.hwagae: 'hwagae',
  ShinsalKind.yangin: 'yangin',
  ShinsalKind.gongmang: 'gongmang',
};
