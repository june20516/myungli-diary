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

  @JsonKey(name: r'source', required: false, includeIfNull: false)
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
  subscription(r'subscription');

  const InsightSource_Enum(this.value);

  final String value;

  @override
  String toString() => value;
}
