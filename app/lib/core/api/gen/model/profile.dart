//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Profile {
  /// Returns a new [Profile] instance.
  Profile({
    required this.honorific,

    required this.language,

    required this.currentTimezone,

    required this.birth,

    required this.notification,

    this.birthCity,
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

  /// 현재 기기 시간대 IANA 이름
  @JsonKey(name: r'currentTimezone', required: true, includeIfNull: false)
  final String currentTimezone;

  @JsonKey(name: r'birth', required: true, includeIfNull: false)
  final Birth birth;

  @JsonKey(name: r'notification', required: true, includeIfNull: false)
  final NotificationSetting notification;

  @JsonKey(name: r'birthCity', required: false, includeIfNull: false)
  final City? birthCity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile &&
          other.honorific == honorific &&
          other.language == language &&
          other.currentTimezone == currentTimezone &&
          other.birth == birth &&
          other.notification == notification &&
          other.birthCity == birthCity;

  @override
  int get hashCode =>
      honorific.hashCode +
      language.hashCode +
      currentTimezone.hashCode +
      birth.hashCode +
      notification.hashCode +
      birthCity.hashCode;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
