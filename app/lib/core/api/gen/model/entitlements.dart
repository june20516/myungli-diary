//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'entitlements.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Entitlements {
  /// Returns a new [Entitlements] instance.
  Entitlements({required this.adFree, required this.insight});

  @JsonKey(name: r'adFree', required: true, includeIfNull: false)
  final AdFree adFree;

  @JsonKey(name: r'insight', required: true, includeIfNull: false)
  final Insight insight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entitlements &&
          other.adFree == adFree &&
          other.insight == insight;

  @override
  int get hashCode => adFree.hashCode + insight.hashCode;

  factory Entitlements.fromJson(Map<String, dynamic> json) =>
      _$EntitlementsFromJson(json);

  Map<String, dynamic> toJson() => _$EntitlementsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
