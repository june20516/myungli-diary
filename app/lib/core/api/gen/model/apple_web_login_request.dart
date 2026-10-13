//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'apple_web_login_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AppleWebLoginRequest {
  /// Returns a new [AppleWebLoginRequest] instance.
  AppleWebLoginRequest({required this.exchangeCode, required this.nonce});

  /// `appleCallback`이 app link로 넘긴 교환 코드(256비트 난수의 base64url, 패딩 없음)
  @JsonKey(name: r'exchangeCode', required: true, includeIfNull: false)
  final String exchangeCode;

  /// nonce 원문입니다. app은 제공자(카카오·Apple)에게 이 원문의 SHA-256 소문자 hex를 nonce로 보냅니다. server는 Apple id_token의 `nonce` claim이 SHA-256(원문) hex와 같은지 확인합니다.
  @JsonKey(name: r'nonce', required: true, includeIfNull: false)
  final String nonce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppleWebLoginRequest &&
          other.exchangeCode == exchangeCode &&
          other.nonce == nonce;

  @override
  int get hashCode => exchangeCode.hashCode + nonce.hashCode;

  factory AppleWebLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$AppleWebLoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AppleWebLoginRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
