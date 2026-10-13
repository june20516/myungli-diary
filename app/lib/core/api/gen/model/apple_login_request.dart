//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'apple_login_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AppleLoginRequest {
  /// Returns a new [AppleLoginRequest] instance.
  AppleLoginRequest({
    required this.idToken,

    required this.authorizationCode,

    required this.nonce,
  });

  /// Apple identity_token
  @JsonKey(name: r'idToken', required: true, includeIfNull: false)
  final String idToken;

  @JsonKey(name: r'authorizationCode', required: true, includeIfNull: false)
  final String authorizationCode;

  /// nonce 원문입니다. app은 제공자(카카오·Apple)에게 이 원문의 SHA-256 소문자 hex를 nonce로 보냅니다. server는 id_token의 `nonce` claim이 SHA-256(원문) hex와 같은지 확인합니다.
  @JsonKey(name: r'nonce', required: true, includeIfNull: false)
  final String nonce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppleLoginRequest &&
          other.idToken == idToken &&
          other.authorizationCode == authorizationCode &&
          other.nonce == nonce;

  @override
  int get hashCode =>
      idToken.hashCode + authorizationCode.hashCode + nonce.hashCode;

  factory AppleLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$AppleLoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AppleLoginRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
