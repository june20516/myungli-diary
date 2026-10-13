//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'login_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LoginResponse {
  /// Returns a new [LoginResponse] instance.
  LoginResponse({
    required this.tokens,

    required this.isNewAccount,

    required this.consentRequired,

    required this.restoredFromDeletion,
  });

  @JsonKey(name: r'tokens', required: true, includeIfNull: false)
  final TokenPair tokens;

  @JsonKey(name: r'isNewAccount', required: true, includeIfNull: false)
  final bool isNewAccount;

  @JsonKey(name: r'consentRequired', required: true, includeIfNull: false)
  final bool consentRequired;

  /// 삭제 대기 중이던 계정이 이 로그인으로 되돌아왔는지
  @JsonKey(name: r'restoredFromDeletion', required: true, includeIfNull: false)
  final bool restoredFromDeletion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginResponse &&
          other.tokens == tokens &&
          other.isNewAccount == isNewAccount &&
          other.consentRequired == consentRequired &&
          other.restoredFromDeletion == restoredFromDeletion;

  @override
  int get hashCode =>
      tokens.hashCode +
      isNewAccount.hashCode +
      consentRequired.hashCode +
      restoredFromDeletion.hashCode;

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
