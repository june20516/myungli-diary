//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daeun_period.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DaeunPeriod {
  /// Returns a new [DaeunPeriod] instance.
  DaeunPeriod({
    required this.pillar,

    required this.startAge,

    required this.startAgeKorean,

    required this.stemTenGod,

    required this.branchTenGod,

    required this.twelveStage,
  });

  @JsonKey(name: r'pillar', required: true, includeIfNull: false)
  final Pillar pillar;

  /// 만 나이
  @JsonKey(name: r'startAge', required: true, includeIfNull: false)
  final int startAge;

  /// 한국식 나이
  @JsonKey(name: r'startAgeKorean', required: true, includeIfNull: false)
  final int startAgeKorean;

  @JsonKey(name: r'stemTenGod', required: true, includeIfNull: false)
  final TenGod stemTenGod;

  @JsonKey(name: r'branchTenGod', required: true, includeIfNull: false)
  final TenGod branchTenGod;

  @JsonKey(name: r'twelveStage', required: true, includeIfNull: false)
  final TwelveStage twelveStage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DaeunPeriod &&
          other.pillar == pillar &&
          other.startAge == startAge &&
          other.startAgeKorean == startAgeKorean &&
          other.stemTenGod == stemTenGod &&
          other.branchTenGod == branchTenGod &&
          other.twelveStage == twelveStage;

  @override
  int get hashCode =>
      pillar.hashCode +
      startAge.hashCode +
      startAgeKorean.hashCode +
      stemTenGod.hashCode +
      branchTenGod.hashCode +
      twelveStage.hashCode;

  factory DaeunPeriod.fromJson(Map<String, dynamic> json) =>
      _$DaeunPeriodFromJson(json);

  Map<String, dynamic> toJson() => _$DaeunPeriodToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
