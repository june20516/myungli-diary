//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/field_error.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileResponse {
  /// Returns a new [ProfileResponse] instance.
  ProfileResponse({required this.profile, required this.warnings});

  @JsonKey(name: r'profile', required: true, includeIfNull: false)
  final Profile profile;

  /// 오류가 아닌 호칭 경고. `code`는 `name.suffix_stripped` 또는 `name.suffix_warning`입니다.
  @JsonKey(name: r'warnings', required: true, includeIfNull: false)
  final List<FieldError> warnings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileResponse &&
          other.profile == profile &&
          other.warnings == warnings;

  @override
  int get hashCode => profile.hashCode + warnings.hashCode;

  factory ProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$ProfileResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
