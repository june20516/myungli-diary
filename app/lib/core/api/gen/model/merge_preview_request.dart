//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'merge_preview_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MergePreviewRequest {
  /// Returns a new [MergePreviewRequest] instance.
  MergePreviewRequest({
    required this.provider,

    this.idToken,

    this.authorizationCode,

    this.exchangeCode,

    required this.nonce,
  });

  @JsonKey(
    name: r'provider',
    required: true,
    includeIfNull: false,
    unknownEnumValue: LoginProvider.unknownDefaultOpenApi,
  )
  final LoginProvider provider;

  /// 제공자 OIDC id_token(Apple은 identity_token)
  @JsonKey(name: r'idToken', required: false, includeIfNull: false)
  final String? idToken;

  /// Apple authorization_code. apple(iOS)에서만 씁니다.
  @JsonKey(name: r'authorizationCode', required: false, includeIfNull: false)
  final String? authorizationCode;

  /// `appleCallback`이 app link로 넘긴 교환 코드(256비트 난수의 base64url, 패딩 없음). apple(Android 웹 흐름)에서만 씁니다.
  @JsonKey(name: r'exchangeCode', required: false, includeIfNull: false)
  final String? exchangeCode;

  /// nonce 원문입니다. app은 제공자에게 이 원문의 SHA-256 소문자 hex를 nonce로 보냅니다. server는 id_token의 `nonce` claim이 SHA-256(원문) hex와 같은지 확인합니다.
  @JsonKey(name: r'nonce', required: true, includeIfNull: false)
  final String nonce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergePreviewRequest &&
          other.provider == provider &&
          other.idToken == idToken &&
          other.authorizationCode == authorizationCode &&
          other.exchangeCode == exchangeCode &&
          other.nonce == nonce;

  @override
  int get hashCode =>
      provider.hashCode +
      idToken.hashCode +
      authorizationCode.hashCode +
      exchangeCode.hashCode +
      nonce.hashCode;

  factory MergePreviewRequest.fromJson(Map<String, dynamic> json) =>
      _$MergePreviewRequestFromJson(json);

  Map<String, dynamic> toJson() => _$MergePreviewRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
