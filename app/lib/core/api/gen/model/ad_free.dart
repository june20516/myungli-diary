//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ad_free.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdFree {
  /// Returns a new [AdFree] instance.
  AdFree({required this.active, this.expiresAt});

  @JsonKey(name: r'active', required: true, includeIfNull: false)
  final bool active;

  @JsonKey(name: r'expiresAt', required: false, includeIfNull: false)
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdFree && other.active == active && other.expiresAt == expiresAt;

  @override
  int get hashCode => active.hashCode + expiresAt.hashCode;

  factory AdFree.fromJson(Map<String, dynamic> json) => _$AdFreeFromJson(json);

  Map<String, dynamic> toJson() => _$AdFreeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
