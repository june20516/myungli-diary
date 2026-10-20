//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'insight.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Insight {
  /// Returns a new [Insight] instance.
  Insight({required this.active, this.expiresAt, this.source_});

  @JsonKey(name: r'active', required: true, includeIfNull: false)
  final bool active;

  @JsonKey(name: r'expiresAt', required: false, includeIfNull: false)
  final DateTime? expiresAt;

  @JsonKey(
    name: r'source',
    required: false,
    includeIfNull: false,
    unknownEnumValue: InsightSource_Enum.unknownDefaultOpenApi,
  )
  final InsightSource_Enum? source_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Insight &&
          other.active == active &&
          other.expiresAt == expiresAt &&
          other.source_ == source_;

  @override
  int get hashCode => active.hashCode + expiresAt.hashCode + source_.hashCode;

  factory Insight.fromJson(Map<String, dynamic> json) =>
      _$InsightFromJson(json);

  Map<String, dynamic> toJson() => _$InsightToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum InsightSource_Enum {
  @JsonValue(r'rewarded_ad')
  rewardedAd(r'rewarded_ad'),
  @JsonValue(r'ad_free_pass')
  adFreePass(r'ad_free_pass'),
  @JsonValue(r'subscription')
  subscription(r'subscription'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const InsightSource_Enum(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
