// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DailyCWProxy {
  Daily date(String date);

  Daily rulesetVersion(String rulesetVersion);

  Daily evidenceAccess(EvidenceAccess evidenceAccess);

  Daily dayPillar(Pillar dayPillar);

  Daily dayKind(DayKind dayKind);

  Daily characterReason(SlotText characterReason);

  Daily fortune(Fortune fortune);

  Daily guide(SlotText guide);

  Daily cards(DailyCards cards);

  Daily tags(DayTags tags);

  Daily relations(List<Relation> relations);

  Daily notices(List<Notice> notices);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Daily(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Daily(...).copyWith(id: 12, name: "My name")
  /// ```
  Daily call({
    String date,
    String rulesetVersion,
    EvidenceAccess evidenceAccess,
    Pillar dayPillar,
    DayKind dayKind,
    SlotText characterReason,
    Fortune fortune,
    SlotText guide,
    DailyCards cards,
    DayTags tags,
    List<Relation> relations,
    List<Notice> notices,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDaily.copyWith(...)` or call `instanceOfDaily.copyWith.fieldName(value)` for a single field.
class _$DailyCWProxyImpl implements _$DailyCWProxy {
  const _$DailyCWProxyImpl(this._value);

  final Daily _value;

  @override
  Daily date(String date) => call(date: date);

  @override
  Daily rulesetVersion(String rulesetVersion) =>
      call(rulesetVersion: rulesetVersion);

  @override
  Daily evidenceAccess(EvidenceAccess evidenceAccess) =>
      call(evidenceAccess: evidenceAccess);

  @override
  Daily dayPillar(Pillar dayPillar) => call(dayPillar: dayPillar);

  @override
  Daily dayKind(DayKind dayKind) => call(dayKind: dayKind);

  @override
  Daily characterReason(SlotText characterReason) =>
      call(characterReason: characterReason);

  @override
  Daily fortune(Fortune fortune) => call(fortune: fortune);

  @override
  Daily guide(SlotText guide) => call(guide: guide);

  @override
  Daily cards(DailyCards cards) => call(cards: cards);

  @override
  Daily tags(DayTags tags) => call(tags: tags);

  @override
  Daily relations(List<Relation> relations) => call(relations: relations);

  @override
  Daily notices(List<Notice> notices) => call(notices: notices);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Daily(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Daily(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Daily call({
    Object? date = const $CopyWithPlaceholder(),
    Object? rulesetVersion = const $CopyWithPlaceholder(),
    Object? evidenceAccess = const $CopyWithPlaceholder(),
    Object? dayPillar = const $CopyWithPlaceholder(),
    Object? dayKind = const $CopyWithPlaceholder(),
    Object? characterReason = const $CopyWithPlaceholder(),
    Object? fortune = const $CopyWithPlaceholder(),
    Object? guide = const $CopyWithPlaceholder(),
    Object? cards = const $CopyWithPlaceholder(),
    Object? tags = const $CopyWithPlaceholder(),
    Object? relations = const $CopyWithPlaceholder(),
    Object? notices = const $CopyWithPlaceholder(),
  }) {
    return Daily(
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String,
      rulesetVersion:
          rulesetVersion == const $CopyWithPlaceholder() ||
              rulesetVersion == null
          ? _value.rulesetVersion
          // ignore: cast_nullable_to_non_nullable
          : rulesetVersion as String,
      evidenceAccess:
          evidenceAccess == const $CopyWithPlaceholder() ||
              evidenceAccess == null
          ? _value.evidenceAccess
          // ignore: cast_nullable_to_non_nullable
          : evidenceAccess as EvidenceAccess,
      dayPillar: dayPillar == const $CopyWithPlaceholder() || dayPillar == null
          ? _value.dayPillar
          // ignore: cast_nullable_to_non_nullable
          : dayPillar as Pillar,
      dayKind: dayKind == const $CopyWithPlaceholder() || dayKind == null
          ? _value.dayKind
          // ignore: cast_nullable_to_non_nullable
          : dayKind as DayKind,
      characterReason:
          characterReason == const $CopyWithPlaceholder() ||
              characterReason == null
          ? _value.characterReason
          // ignore: cast_nullable_to_non_nullable
          : characterReason as SlotText,
      fortune: fortune == const $CopyWithPlaceholder() || fortune == null
          ? _value.fortune
          // ignore: cast_nullable_to_non_nullable
          : fortune as Fortune,
      guide: guide == const $CopyWithPlaceholder() || guide == null
          ? _value.guide
          // ignore: cast_nullable_to_non_nullable
          : guide as SlotText,
      cards: cards == const $CopyWithPlaceholder() || cards == null
          ? _value.cards
          // ignore: cast_nullable_to_non_nullable
          : cards as DailyCards,
      tags: tags == const $CopyWithPlaceholder() || tags == null
          ? _value.tags
          // ignore: cast_nullable_to_non_nullable
          : tags as DayTags,
      relations: relations == const $CopyWithPlaceholder() || relations == null
          ? _value.relations
          // ignore: cast_nullable_to_non_nullable
          : relations as List<Relation>,
      notices: notices == const $CopyWithPlaceholder() || notices == null
          ? _value.notices
          // ignore: cast_nullable_to_non_nullable
          : notices as List<Notice>,
    );
  }
}

extension $DailyCopyWith on Daily {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDaily.copyWith(...)` or `instanceOfDaily.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DailyCWProxy get copyWith => _$DailyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Daily _$DailyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Daily', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'date',
          'rulesetVersion',
          'evidenceAccess',
          'dayPillar',
          'dayKind',
          'characterReason',
          'fortune',
          'guide',
          'cards',
          'tags',
          'relations',
          'notices',
        ],
      );
      final val = Daily(
        date: $checkedConvert('date', (v) => v as String),
        rulesetVersion: $checkedConvert('rulesetVersion', (v) => v as String),
        evidenceAccess: $checkedConvert(
          'evidenceAccess',
          (v) => $enumDecode(_$EvidenceAccessEnumMap, v),
        ),
        dayPillar: $checkedConvert(
          'dayPillar',
          (v) => Pillar.fromJson(v as Map<String, dynamic>),
        ),
        dayKind: $checkedConvert(
          'dayKind',
          (v) => $enumDecode(_$DayKindEnumMap, v),
        ),
        characterReason: $checkedConvert(
          'characterReason',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
        fortune: $checkedConvert(
          'fortune',
          (v) => Fortune.fromJson(v as Map<String, dynamic>),
        ),
        guide: $checkedConvert(
          'guide',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
        cards: $checkedConvert(
          'cards',
          (v) => DailyCards.fromJson(v as Map<String, dynamic>),
        ),
        tags: $checkedConvert(
          'tags',
          (v) => DayTags.fromJson(v as Map<String, dynamic>),
        ),
        relations: $checkedConvert(
          'relations',
          (v) => (v as List<dynamic>)
              .map((e) => Relation.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        notices: $checkedConvert(
          'notices',
          (v) => (v as List<dynamic>)
              .map((e) => Notice.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DailyToJson(Daily instance) => <String, dynamic>{
  'date': instance.date,
  'rulesetVersion': instance.rulesetVersion,
  'evidenceAccess': _$EvidenceAccessEnumMap[instance.evidenceAccess]!,
  'dayPillar': instance.dayPillar.toJson(),
  'dayKind': _$DayKindEnumMap[instance.dayKind]!,
  'characterReason': instance.characterReason.toJson(),
  'fortune': instance.fortune.toJson(),
  'guide': instance.guide.toJson(),
  'cards': instance.cards.toJson(),
  'tags': instance.tags.toJson(),
  'relations': instance.relations.map((e) => e.toJson()).toList(),
  'notices': instance.notices.map((e) => e.toJson()).toList(),
};

const _$EvidenceAccessEnumMap = {
  EvidenceAccess.unlocked: 'unlocked',
  EvidenceAccess.locked: 'locked',
};

const _$DayKindEnumMap = {
  DayKind.gwiinDay: 'gwiin_day',
  DayKind.yongsinDay: 'yongsin_day',
  DayKind.gisinDay: 'gisin_day',
  DayKind.ordinaryDay: 'ordinary_day',
};
