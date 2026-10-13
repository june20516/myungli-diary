// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_day.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CalendarDayCWProxy {
  CalendarDay date(String date);

  CalendarDay pillar(Pillar pillar);

  CalendarDay lunar(LunarDate lunar);

  CalendarDay solarTerm(SolarTerm? solarTerm);

  CalendarDay dayKind(DayKind dayKind);

  CalendarDay luckLevel(LuckLevel luckLevel);

  CalendarDay score(int score);

  CalendarDay scoreItems(List<ScoreItem> scoreItems);

  CalendarDay featuredTag(Tag? featuredTag);

  CalendarDay level(SlotText level);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CalendarDay(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CalendarDay(...).copyWith(id: 12, name: "My name")
  /// ```
  CalendarDay call({
    String date,
    Pillar pillar,
    LunarDate lunar,
    SolarTerm? solarTerm,
    DayKind dayKind,
    LuckLevel luckLevel,
    int score,
    List<ScoreItem> scoreItems,
    Tag? featuredTag,
    SlotText level,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCalendarDay.copyWith(...)` or call `instanceOfCalendarDay.copyWith.fieldName(value)` for a single field.
class _$CalendarDayCWProxyImpl implements _$CalendarDayCWProxy {
  const _$CalendarDayCWProxyImpl(this._value);

  final CalendarDay _value;

  @override
  CalendarDay date(String date) => call(date: date);

  @override
  CalendarDay pillar(Pillar pillar) => call(pillar: pillar);

  @override
  CalendarDay lunar(LunarDate lunar) => call(lunar: lunar);

  @override
  CalendarDay solarTerm(SolarTerm? solarTerm) => call(solarTerm: solarTerm);

  @override
  CalendarDay dayKind(DayKind dayKind) => call(dayKind: dayKind);

  @override
  CalendarDay luckLevel(LuckLevel luckLevel) => call(luckLevel: luckLevel);

  @override
  CalendarDay score(int score) => call(score: score);

  @override
  CalendarDay scoreItems(List<ScoreItem> scoreItems) =>
      call(scoreItems: scoreItems);

  @override
  CalendarDay featuredTag(Tag? featuredTag) => call(featuredTag: featuredTag);

  @override
  CalendarDay level(SlotText level) => call(level: level);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CalendarDay(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CalendarDay(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CalendarDay call({
    Object? date = const $CopyWithPlaceholder(),
    Object? pillar = const $CopyWithPlaceholder(),
    Object? lunar = const $CopyWithPlaceholder(),
    Object? solarTerm = const $CopyWithPlaceholder(),
    Object? dayKind = const $CopyWithPlaceholder(),
    Object? luckLevel = const $CopyWithPlaceholder(),
    Object? score = const $CopyWithPlaceholder(),
    Object? scoreItems = const $CopyWithPlaceholder(),
    Object? featuredTag = const $CopyWithPlaceholder(),
    Object? level = const $CopyWithPlaceholder(),
  }) {
    return CalendarDay(
      date: date == const $CopyWithPlaceholder() || date == null
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as String,
      pillar: pillar == const $CopyWithPlaceholder() || pillar == null
          ? _value.pillar
          // ignore: cast_nullable_to_non_nullable
          : pillar as Pillar,
      lunar: lunar == const $CopyWithPlaceholder() || lunar == null
          ? _value.lunar
          // ignore: cast_nullable_to_non_nullable
          : lunar as LunarDate,
      solarTerm: solarTerm == const $CopyWithPlaceholder()
          ? _value.solarTerm
          // ignore: cast_nullable_to_non_nullable
          : solarTerm as SolarTerm?,
      dayKind: dayKind == const $CopyWithPlaceholder() || dayKind == null
          ? _value.dayKind
          // ignore: cast_nullable_to_non_nullable
          : dayKind as DayKind,
      luckLevel: luckLevel == const $CopyWithPlaceholder() || luckLevel == null
          ? _value.luckLevel
          // ignore: cast_nullable_to_non_nullable
          : luckLevel as LuckLevel,
      score: score == const $CopyWithPlaceholder() || score == null
          ? _value.score
          // ignore: cast_nullable_to_non_nullable
          : score as int,
      scoreItems:
          scoreItems == const $CopyWithPlaceholder() || scoreItems == null
          ? _value.scoreItems
          // ignore: cast_nullable_to_non_nullable
          : scoreItems as List<ScoreItem>,
      featuredTag: featuredTag == const $CopyWithPlaceholder()
          ? _value.featuredTag
          // ignore: cast_nullable_to_non_nullable
          : featuredTag as Tag?,
      level: level == const $CopyWithPlaceholder() || level == null
          ? _value.level
          // ignore: cast_nullable_to_non_nullable
          : level as SlotText,
    );
  }
}

extension $CalendarDayCopyWith on CalendarDay {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCalendarDay.copyWith(...)` or `instanceOfCalendarDay.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CalendarDayCWProxy get copyWith => _$CalendarDayCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CalendarDay _$CalendarDayFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CalendarDay', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'date',
          'pillar',
          'lunar',
          'dayKind',
          'luckLevel',
          'score',
          'scoreItems',
          'level',
        ],
      );
      final val = CalendarDay(
        date: $checkedConvert('date', (v) => v as String),
        pillar: $checkedConvert(
          'pillar',
          (v) => Pillar.fromJson(v as Map<String, dynamic>),
        ),
        lunar: $checkedConvert(
          'lunar',
          (v) => LunarDate.fromJson(v as Map<String, dynamic>),
        ),
        solarTerm: $checkedConvert(
          'solarTerm',
          (v) =>
              v == null ? null : SolarTerm.fromJson(v as Map<String, dynamic>),
        ),
        dayKind: $checkedConvert(
          'dayKind',
          (v) => $enumDecode(_$DayKindEnumMap, v),
        ),
        luckLevel: $checkedConvert(
          'luckLevel',
          (v) => $enumDecode(_$LuckLevelEnumMap, v),
        ),
        score: $checkedConvert('score', (v) => (v as num).toInt()),
        scoreItems: $checkedConvert(
          'scoreItems',
          (v) => (v as List<dynamic>)
              .map((e) => ScoreItem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        featuredTag: $checkedConvert(
          'featuredTag',
          (v) => v == null ? null : Tag.fromJson(v as Map<String, dynamic>),
        ),
        level: $checkedConvert(
          'level',
          (v) => SlotText.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CalendarDayToJson(CalendarDay instance) =>
    <String, dynamic>{
      'date': instance.date,
      'pillar': instance.pillar.toJson(),
      'lunar': instance.lunar.toJson(),
      'solarTerm': ?instance.solarTerm?.toJson(),
      'dayKind': _$DayKindEnumMap[instance.dayKind]!,
      'luckLevel': _$LuckLevelEnumMap[instance.luckLevel]!,
      'score': instance.score,
      'scoreItems': instance.scoreItems.map((e) => e.toJson()).toList(),
      'featuredTag': ?instance.featuredTag?.toJson(),
      'level': instance.level.toJson(),
    };

const _$DayKindEnumMap = {
  DayKind.gwiinDay: 'gwiin_day',
  DayKind.yongsinDay: 'yongsin_day',
  DayKind.gisinDay: 'gisin_day',
  DayKind.ordinaryDay: 'ordinary_day',
};

const _$LuckLevelEnumMap = {
  LuckLevel.good: 'good',
  LuckLevel.neutral: 'neutral',
  LuckLevel.caution: 'caution',
};
