//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_input.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileInput {
  /// Returns a new [ProfileInput] instance.
  ProfileInput({
    required this.honorific,

    required this.language,

    required this.currentTimezone,

    required this.birth,

    required this.notification,
  });

  /// 호칭
  @JsonKey(name: r'honorific', required: true, includeIfNull: false)
  final String honorific;

  @JsonKey(
    name: r'language',
    required: true,
    includeIfNull: false,
    unknownEnumValue: Language.unknownDefaultOpenApi,
  )
  final Language language;

  /// 현재 기기 시간대 IANA 이름. \"오늘\"의 기준입니다.
  @JsonKey(name: r'currentTimezone', required: true, includeIfNull: false)
  final String currentTimezone;

  @JsonKey(name: r'birth', required: true, includeIfNull: false)
  final Birth birth;

  @JsonKey(name: r'notification', required: true, includeIfNull: false)
  final NotificationSetting notification;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileInput &&
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

  factory ProfileInput.fromJson(Map<String, dynamic> json) =>
      _$ProfileInputFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
