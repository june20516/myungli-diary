//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/daily_cards.dart';
import 'package:myungli_diary/core/api/gen/model/relation.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/fortune.dart';
import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/day_tags.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Daily {
  /// Returns a new [Daily] instance.
  Daily({
    required this.date,

    required this.rulesetVersion,

    required this.evidenceAccess,

    required this.dayPillar,

    required this.dayKind,

    required this.characterReason,

    required this.fortune,

    required this.guide,

    required this.cards,

    required this.tags,

    required this.relations,

    required this.notices,
  });

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final String date;

  @JsonKey(name: r'rulesetVersion', required: true, includeIfNull: false)
  final String rulesetVersion;

  @JsonKey(name: r'evidenceAccess', required: true, includeIfNull: false)
  final EvidenceAccess evidenceAccess;

  @JsonKey(name: r'dayPillar', required: true, includeIfNull: false)
  final Pillar dayPillar;

  @JsonKey(name: r'dayKind', required: true, includeIfNull: false)
  final DayKind dayKind;

  @JsonKey(name: r'characterReason', required: true, includeIfNull: false)
  final SlotText characterReason;

  @JsonKey(name: r'fortune', required: true, includeIfNull: false)
  final Fortune fortune;

  @JsonKey(name: r'guide', required: true, includeIfNull: false)
  final SlotText guide;

  @JsonKey(name: r'cards', required: true, includeIfNull: false)
  final DailyCards cards;

  @JsonKey(name: r'tags', required: true, includeIfNull: false)
  final DayTags tags;

  /// 일진과 원국의 관계
  @JsonKey(name: r'relations', required: true, includeIfNull: false)
  final List<Relation> relations;

  @JsonKey(name: r'notices', required: true, includeIfNull: false)
  final List<Notice> notices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Daily &&
          other.date == date &&
          other.rulesetVersion == rulesetVersion &&
          other.evidenceAccess == evidenceAccess &&
          other.dayPillar == dayPillar &&
          other.dayKind == dayKind &&
          other.characterReason == characterReason &&
          other.fortune == fortune &&
          other.guide == guide &&
          other.cards == cards &&
          other.tags == tags &&
          other.relations == relations &&
          other.notices == notices;

  @override
  int get hashCode =>
      date.hashCode +
      rulesetVersion.hashCode +
      evidenceAccess.hashCode +
      dayPillar.hashCode +
      dayKind.hashCode +
      characterReason.hashCode +
      fortune.hashCode +
      guide.hashCode +
      cards.hashCode +
      tags.hashCode +
      relations.hashCode +
      notices.hashCode;

  factory Daily.fromJson(Map<String, dynamic> json) => _$DailyFromJson(json);

  Map<String, dynamic> toJson() => _$DailyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
