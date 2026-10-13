//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_setting.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NotificationSetting {
  /// Returns a new [NotificationSetting] instance.
  NotificationSetting({required this.status, this.time});

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final NotificationSettingStatusEnum status;

  /// HH:MM. 분은 5의 배수이며, 아니면 `pattern` 위반 400 `request.invalid`입니다.
  @JsonKey(name: r'time', required: false, includeIfNull: false)
  final String? time;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSetting &&
          other.status == status &&
          other.time == time;

  @override
  int get hashCode => status.hashCode + time.hashCode;

  factory NotificationSetting.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationSettingToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum NotificationSettingStatusEnum {
  @JsonValue(r'not_asked')
  notAsked(r'not_asked'),
  @JsonValue(r'enabled')
  enabled(r'enabled'),
  @JsonValue(r'disabled')
  disabled(r'disabled');

  const NotificationSettingStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
