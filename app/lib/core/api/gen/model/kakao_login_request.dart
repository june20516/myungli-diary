//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'kakao_login_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class KakaoLoginRequest {
  /// Returns a new [KakaoLoginRequest] instance.
  KakaoLoginRequest({required this.idToken, required this.nonce});

  /// 카카오 OIDC id_token
  @JsonKey(name: r'idToken', required: true, includeIfNull: false)
  final String idToken;

  /// nonce 원문
  @JsonKey(name: r'nonce', required: true, includeIfNull: false)
  final String nonce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KakaoLoginRequest &&
          other.idToken == idToken &&
          other.nonce == nonce;

  @override
  int get hashCode => idToken.hashCode + nonce.hashCode;

  factory KakaoLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$KakaoLoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$KakaoLoginRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
