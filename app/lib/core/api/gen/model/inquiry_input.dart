//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inquiry_input.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class InquiryInput {
  /// Returns a new [InquiryInput] instance.
  InquiryInput({
    required this.message,

    required this.replyEmail,

    required this.appVersion,

    required this.os,

    required this.deviceModel,
  });

  /// 문의 내용. 공백이 아닌 글자가 하나 이상 있어야 합니다.
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  /// 답장 받을 메일 주소(받은 메일의 Reply-To)
  @JsonKey(name: r'replyEmail', required: true, includeIfNull: false)
  final String replyEmail;

  /// 앱 버전과 빌드 번호(예 `1.0.0+4`)
  @JsonKey(name: r'appVersion', required: true, includeIfNull: false)
  final String appVersion;

  /// OS 이름과 버전(예 `Android 15`, `iOS 18.1`)
  @JsonKey(name: r'os', required: true, includeIfNull: false)
  final String os;

  /// 기종(예 `Pixel 8`, `iPhone15,2`)
  @JsonKey(name: r'deviceModel', required: true, includeIfNull: false)
  final String deviceModel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InquiryInput &&
          other.message == message &&
          other.replyEmail == replyEmail &&
          other.appVersion == appVersion &&
          other.os == os &&
          other.deviceModel == deviceModel;

  @override
  int get hashCode =>
      message.hashCode +
      replyEmail.hashCode +
      appVersion.hashCode +
      os.hashCode +
      deviceModel.hashCode;

  factory InquiryInput.fromJson(Map<String, dynamic> json) =>
      _$InquiryInputFromJson(json);

  Map<String, dynamic> toJson() => _$InquiryInputToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
