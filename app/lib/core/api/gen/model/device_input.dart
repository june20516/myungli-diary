//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/device_platform.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'device_input.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeviceInput {
  /// Returns a new [DeviceInput] instance.
  DeviceInput({required this.fcmToken, required this.platform});

  @JsonKey(name: r'fcmToken', required: true, includeIfNull: false)
  final String fcmToken;

  @JsonKey(name: r'platform', required: true, includeIfNull: false)
  final DevicePlatform platform;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInput &&
          other.fcmToken == fcmToken &&
          other.platform == platform;

  @override
  int get hashCode => fcmToken.hashCode + platform.hashCode;

  factory DeviceInput.fromJson(Map<String, dynamic> json) =>
      _$DeviceInputFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
