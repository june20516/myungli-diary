//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'preview_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PreviewRequest {
  /// Returns a new [PreviewRequest] instance.
  PreviewRequest({
    required this.installationId,

    required this.currentTimezone,

    required this.birth,
  });

  /// 앱 설치마다 만든 무작위 값
  @JsonKey(name: r'installationId', required: true, includeIfNull: false)
  final String installationId;

  /// 현재 기기 시간대 IANA 이름
  @JsonKey(name: r'currentTimezone', required: true, includeIfNull: false)
  final String currentTimezone;

  @JsonKey(name: r'birth', required: true, includeIfNull: false)
  final Birth birth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreviewRequest &&
          other.installationId == installationId &&
          other.currentTimezone == currentTimezone &&
          other.birth == birth;

  @override
  int get hashCode =>
      installationId.hashCode + currentTimezone.hashCode + birth.hashCode;

  factory PreviewRequest.fromJson(Map<String, dynamic> json) =>
      _$PreviewRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PreviewRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
