//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'minimum_version.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MinimumVersion {
  /// Returns a new [MinimumVersion] instance.
  MinimumVersion({required this.ios, required this.android});

  @JsonKey(name: r'ios', required: true, includeIfNull: false)
  final String ios;

  @JsonKey(name: r'android', required: true, includeIfNull: false)
  final String android;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinimumVersion && other.ios == ios && other.android == android;

  @override
  int get hashCode => ios.hashCode + android.hashCode;

  factory MinimumVersion.fromJson(Map<String, dynamic> json) =>
      _$MinimumVersionFromJson(json);

  Map<String, dynamic> toJson() => _$MinimumVersionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
