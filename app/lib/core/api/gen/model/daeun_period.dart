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

    required this.startYear,

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

  /// 대운이 실제로 시작하는 양력 연도(엔진 값 그대로). 다음 대운은 10년 뒤입니다. `startAgeKorean` = `startYear` - 출생 양력 연도 + 1이고, 출생 양력 연도는 음력 생일이면 양력으로 바꾼 날짜의 연도입니다.
  @JsonKey(name: r'startYear', required: true, includeIfNull: false)
  final int startYear;

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
          other.startYear == startYear &&
          other.stemTenGod == stemTenGod &&
          other.branchTenGod == branchTenGod &&
          other.twelveStage == twelveStage;

  @override
  int get hashCode =>
      pillar.hashCode +
      startAge.hashCode +
      startAgeKorean.hashCode +
      startYear.hashCode +
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
