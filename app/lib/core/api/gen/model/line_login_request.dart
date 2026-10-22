//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'line_login_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LineLoginRequest {
  /// Returns a new [LineLoginRequest] instance.
  LineLoginRequest({required this.idToken, required this.nonce});

  /// LINE OIDC id_token
  @JsonKey(name: r'idToken', required: true, includeIfNull: false)
  final String idToken;

  /// nonce 원문입니다. app은 제공자에게 이 원문의 SHA-256 소문자 hex를 nonce로 보냅니다. server는 id_token의 `nonce` claim이 SHA-256(원문) hex와 같은지 확인합니다.
  @JsonKey(name: r'nonce', required: true, includeIfNull: false)
  final String nonce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineLoginRequest &&
          other.idToken == idToken &&
          other.nonce == nonce;

  @override
  int get hashCode => idToken.hashCode + nonce.hashCode;

  factory LineLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LineLoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LineLoginRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
