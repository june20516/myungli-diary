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

    required this.clientType,
  });

  /// Apple identity_token
  @JsonKey(name: r'idToken', required: true, includeIfNull: false)
  final String idToken;

  @JsonKey(name: r'authorizationCode', required: true, includeIfNull: false)
  final String authorizationCode;

  /// nonce 원문
  @JsonKey(name: r'nonce', required: true, includeIfNull: false)
  final String nonce;

  /// iOS는 `native`, Android 웹 흐름은 `web`
  @JsonKey(name: r'clientType', required: true, includeIfNull: false)
  final AppleLoginRequestClientTypeEnum clientType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppleLoginRequest &&
          other.idToken == idToken &&
          other.authorizationCode == authorizationCode &&
          other.nonce == nonce &&
          other.clientType == clientType;

  @override
  int get hashCode =>
      idToken.hashCode +
      authorizationCode.hashCode +
      nonce.hashCode +
      clientType.hashCode;

  factory AppleLoginRequest.fromJson(Map<String, dynamic> json) =>
      _$AppleLoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AppleLoginRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

/// iOS는 `native`, Android 웹 흐름은 `web`
enum AppleLoginRequestClientTypeEnum {
  @JsonValue(r'native')
  native_(r'native'),
  @JsonValue(r'web')
  web(r'web');

  const AppleLoginRequestClientTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
