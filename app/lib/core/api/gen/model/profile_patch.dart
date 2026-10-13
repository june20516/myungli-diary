//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_patch.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfilePatch {
  /// Returns a new [ProfilePatch] instance.
  ProfilePatch({
    this.honorific,

    this.language,

    this.currentTimezone,

    this.birth,

    this.notification,
  });

  /// 호칭
  @JsonKey(name: r'honorific', required: false, includeIfNull: false)
  final String? honorific;

  @JsonKey(name: r'language', required: false, includeIfNull: false)
  final Language? language;

  /// 현재 기기 시간대 IANA 이름
  @JsonKey(name: r'currentTimezone', required: false, includeIfNull: false)
  final String? currentTimezone;

  @JsonKey(name: r'birth', required: false, includeIfNull: false)
  final Birth? birth;

  @JsonKey(name: r'notification', required: false, includeIfNull: false)
  final NotificationSetting? notification;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilePatch &&
          other.honorific == honorific &&
          other.language == language &&
          other.currentTimezone == currentTimezone &&
          other.birth == birth &&
          other.notification == notification;

  @override
  int get hashCode =>
      honorific.hashCode +
      language.hashCode +
      currentTimezone.hashCode +
      birth.hashCode +
      notification.hashCode;

  factory ProfilePatch.fromJson(Map<String, dynamic> json) =>
      _$ProfilePatchFromJson(json);

  Map<String, dynamic> toJson() => _$ProfilePatchToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
