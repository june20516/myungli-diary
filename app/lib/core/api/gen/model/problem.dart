//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/field_error.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'problem.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Problem {
  /// Returns a new [Problem] instance.
  Problem({
    required this.type,

    required this.title,

    required this.status,

    required this.code,

    required this.traceId,

    this.detail,

    this.errors,
  });

  /// `https://api.myungli.app/problems/<code>`
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Problem &&
          other.type == type &&
          other.title == title &&
          other.status == status &&
          other.code == code &&
          other.traceId == traceId &&
          other.detail == detail &&
          other.errors == errors;

  @override
  int get hashCode =>
      type.hashCode +
      title.hashCode +
      status.hashCode +
      code.hashCode +
      traceId.hashCode +
      detail.hashCode +
      errors.hashCode;

  factory Problem.fromJson(Map<String, dynamic> json) =>
      _$ProblemFromJson(json);

  Map<String, dynamic> toJson() => _$ProblemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
