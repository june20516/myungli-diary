//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/hidden_stems_at.dart';
import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god_at.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_at.dart';
import 'package:myungli_diary/core/api/gen/model/seun_year.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage_at.dart';
import 'package:myungli_diary/core/api/gen/model/daeun.dart';
import 'package:myungli_diary/core/api/gen/model/yongsin.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/chart_pillars.dart';
import 'package:myungli_diary/core/api/gen/model/element_weight.dart';
import 'package:myungli_diary/core/api/gen/model/strength.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chart.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Chart {
  /// Returns a new [Chart] instance.
  Chart({
    required this.rulesetVersion,

    required this.evidenceAccess,

    required this.pillars,

    required this.tenGods,

    required this.hiddenStems,

    required this.twelveStages,

    required this.shinsal,

    required this.gongmang,

    required this.elementWeights,

    required this.strength,

    required this.yongsin,

    required this.daeun,

    required this.seun,

    required this.notices,

    this.personalReadings,
  });

  @JsonKey(name: r'rulesetVersion', required: true, includeIfNull: false)
  final String rulesetVersion;

  @JsonKey(name: r'evidenceAccess', required: true, includeIfNull: false)
  final EvidenceAccess evidenceAccess;

  @JsonKey(name: r'pillars', required: true, includeIfNull: false)
  final ChartPillars pillars;

  @JsonKey(name: r'tenGods', required: true, includeIfNull: false)
  final List<TenGodAt> tenGods;

  @JsonKey(name: r'hiddenStems', required: true, includeIfNull: false)
  final List<HiddenStemsAt> hiddenStems;

  @JsonKey(name: r'twelveStages', required: true, includeIfNull: false)
  final List<TwelveStageAt> twelveStages;

  @JsonKey(name: r'shinsal', required: true, includeIfNull: false)
  final List<ShinsalAt> shinsal;

  @JsonKey(name: r'gongmang', required: true, includeIfNull: false)
  final List<Branch> gongmang;

  @JsonKey(name: r'elementWeights', required: true, includeIfNull: false)
  final List<ElementWeight> elementWeights;

  @JsonKey(name: r'strength', required: true, includeIfNull: false)
  final Strength strength;

  @JsonKey(name: r'yongsin', required: true, includeIfNull: false)
  final Yongsin yongsin;

  @JsonKey(name: r'daeun', required: true, includeIfNull: false)
  final Daeun daeun;

  @JsonKey(name: r'seun', required: true, includeIfNull: false)
  final List<SeunYear> seun;

  @JsonKey(name: r'notices', required: true, includeIfNull: false)
  final List<Notice> notices;

  /// 원국 개인 해석(\"내 사주에서는\")입니다. 근거 열람 권한이 없으면(`evidenceAccess: locked`) 이 필드가 없습니다(D60). 원고가 없는 항목은 빠집니다. 앱은 누른 용어의 (`kind`, `position`, `index`, `shinsal`)로 항목을 찾습니다.
  @JsonKey(name: r'personalReadings', required: false, includeIfNull: false)
  final List<PersonalReading>? personalReadings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chart &&
          other.rulesetVersion == rulesetVersion &&
          other.evidenceAccess == evidenceAccess &&
          other.pillars == pillars &&
          other.tenGods == tenGods &&
          other.hiddenStems == hiddenStems &&
          other.twelveStages == twelveStages &&
          other.shinsal == shinsal &&
          other.gongmang == gongmang &&
          other.elementWeights == elementWeights &&
          other.strength == strength &&
          other.yongsin == yongsin &&
          other.daeun == daeun &&
          other.seun == seun &&
          other.notices == notices &&
          other.personalReadings == personalReadings;

  @override
  int get hashCode =>
      rulesetVersion.hashCode +
      evidenceAccess.hashCode +
      pillars.hashCode +
      tenGods.hashCode +
      hiddenStems.hashCode +
      twelveStages.hashCode +
      shinsal.hashCode +
      gongmang.hashCode +
      elementWeights.hashCode +
      strength.hashCode +
      yongsin.hashCode +
      daeun.hashCode +
      seun.hashCode +
      notices.hashCode +
      personalReadings.hashCode;

  factory Chart.fromJson(Map<String, dynamic> json) => _$ChartFromJson(json);

  Map<String, dynamic> toJson() => _$ChartToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
