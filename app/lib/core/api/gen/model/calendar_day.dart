//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/lunar_date.dart';
import 'package:myungli_diary/core/api/gen/model/solar_term.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/luck_level.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'calendar_day.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CalendarDay {
  /// Returns a new [CalendarDay] instance.
  CalendarDay({
    required this.date,

    required this.pillar,

    required this.lunar,

    this.solarTerm,

    required this.dayKind,

    required this.characterReason,

    required this.luckLevel,

    required this.score,

    required this.level,
  });

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'pillar', required: true, includeIfNull: false)
  final Pillar pillar;

  @JsonKey(name: r'lunar', required: true, includeIfNull: false)
  final LunarDate lunar;

  @JsonKey(name: r'solarTerm', required: false, includeIfNull: false)
  final SolarTerm? solarTerm;

  @JsonKey(name: r'dayKind', required: true, includeIfNull: false)
  final DayKind dayKind;

  @JsonKey(name: r'characterReason', required: true, includeIfNull: false)
  final SlotText characterReason;

  @JsonKey(name: r'luckLevel', required: true, includeIfNull: false)
  final LuckLevel luckLevel;

  @JsonKey(name: r'score', required: true, includeIfNull: false)
  final int score;

  @JsonKey(name: r'level', required: true, includeIfNull: false)
  final SlotText level;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarDay &&
          other.date == date &&
          other.pillar == pillar &&
          other.lunar == lunar &&
          other.solarTerm == solarTerm &&
          other.dayKind == dayKind &&
          other.characterReason == characterReason &&
          other.luckLevel == luckLevel &&
          other.score == score &&
          other.level == level;

  @override
  int get hashCode =>
      date.hashCode +
      pillar.hashCode +
      lunar.hashCode +
      solarTerm.hashCode +
      dayKind.hashCode +
      characterReason.hashCode +
      luckLevel.hashCode +
      score.hashCode +
      level.hashCode;

  factory CalendarDay.fromJson(Map<String, dynamic> json) =>
      _$CalendarDayFromJson(json);

  Map<String, dynamic> toJson() => _$CalendarDayToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
