//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'me.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Me {
  /// Returns a new [Me] instance.
  Me({
    required this.accountId,

    required this.consentRequired,

    required this.requiredConsents,

    required this.hasProfile,

    required this.adFree,

    required this.insight,
  });

  @JsonKey(name: r'accountId', required: true, includeIfNull: false)
  final String accountId;

  @JsonKey(name: r'consentRequired', required: true, includeIfNull: false)
  final bool consentRequired;

  /// 동의해야 할 문서와 현재 버전
  @JsonKey(name: r'requiredConsents', required: true, includeIfNull: false)
  final List<ConsentDocument> requiredConsents;

  @JsonKey(name: r'hasProfile', required: true, includeIfNull: false)
  final bool hasProfile;

  @JsonKey(name: r'adFree', required: true, includeIfNull: false)
  final AdFree adFree;

  @JsonKey(name: r'insight', required: true, includeIfNull: false)
  final Insight insight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Me &&
          other.accountId == accountId &&
          other.consentRequired == consentRequired &&
          other.requiredConsents == requiredConsents &&
          other.hasProfile == hasProfile &&
          other.adFree == adFree &&
          other.insight == insight;

  @override
  int get hashCode =>
      accountId.hashCode +
      consentRequired.hashCode +
      requiredConsents.hashCode +
      hasProfile.hashCode +
      adFree.hashCode +
      insight.hashCode;

  factory Me.fromJson(Map<String, dynamic> json) => _$MeFromJson(json);

  Map<String, dynamic> toJson() => _$MeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
