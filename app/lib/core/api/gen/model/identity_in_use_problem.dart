//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/field_error.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'identity_in_use_problem.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class IdentityInUseProblem {
  /// Returns a new [IdentityInUseProblem] instance.
  IdentityInUseProblem({
    required this.type,

    required this.title,

    required this.status,

    required this.code,

    required this.traceId,

    this.detail,

    this.errors,

    this.mergeToken,

    this.expiresAt,
  });

  /// `https://api.myungli.app/problems/<code>`. 도메인은 바뀔 수 있어 app은 `code`로 구분합니다.
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  /// 개발자용 영어 제목. 사용자에게 보이지 않습니다.
  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final int status;

  /// 오류 코드. app은 이 값으로 UI 문구를 고릅니다. 가능한 값과 상태는 `x-problem-codes`입니다. 목록에 없는 code가 오면 status 대역의 기본 문구를 씁니다(목록은 하위 호환으로 늘어납니다).
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  /// 문의가 왔을 때 server 로그를 찾는 값
  @JsonKey(name: r'traceId', required: true, includeIfNull: false)
  final String traceId;

  @JsonKey(name: r'detail', required: false, includeIfNull: false)
  final String? detail;

  @JsonKey(name: r'errors', required: false, includeIfNull: false)
  final List<FieldError>? errors;

  /// 합치기 토큰(랜덤 32바이트, base64url 패딩 없음). 일회용이고 현재 계정의 bearer만 쓸 수 있습니다. URL에 넣지 않습니다.
  @JsonKey(name: r'mergeToken', required: false, includeIfNull: false)
  final String? mergeToken;

  /// 합치기 토큰 만료 시각(발급 + 10분)
  @JsonKey(name: r'expiresAt', required: false, includeIfNull: false)
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentityInUseProblem &&
          other.type == type &&
          other.title == title &&
          other.status == status &&
          other.code == code &&
          other.traceId == traceId &&
          other.detail == detail &&
          other.errors == errors &&
          other.mergeToken == mergeToken &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      type.hashCode +
      title.hashCode +
      status.hashCode +
      code.hashCode +
      traceId.hashCode +
      detail.hashCode +
      errors.hashCode +
      mergeToken.hashCode +
      expiresAt.hashCode;

  factory IdentityInUseProblem.fromJson(Map<String, dynamic> json) =>
      _$IdentityInUseProblemFromJson(json);

  Map<String, dynamic> toJson() => _$IdentityInUseProblemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
