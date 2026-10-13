//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'field_error.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FieldError {
  /// Returns a new [FieldError] instance.
  FieldError({required this.field, required this.code});

  /// 위반 위치. 요청 본문 안이면 JSON Pointer(RFC 6901)입니다(예 `/birth/date/day`, 본문 전체는 빈 문자열). 경로·쿼리·헤더 parameter면 계약의 parameter 이름입니다(예 `date`, `limit`). JSON Pointer는 `/`로 시작하거나 비어 있어 둘은 겹치지 않습니다.
  @JsonKey(name: r'field', required: true, includeIfNull: false)
  final String field;

  /// `request.invalid`에서는 위반한 JSON Schema keyword(예 `required`, `pattern`, `minimum`, `format`)이고, parameter를 타입으로 읽지 못하면 `type`입니다. `request.inconsistent`에서는 `required_by_status`(상태가 요구하는 값이 없음) 또는 `forbidden_by_status`(상태가 허용하지 않는 값이 있음)입니다. 그 밖(예 `ProfileResponse.warnings`)에서는 그 응답이 정한 코드입니다.
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldError && other.field == field && other.code == code;

  @override
  int get hashCode => field.hashCode + code.hashCode;

  factory FieldError.fromJson(Map<String, dynamic> json) =>
      _$FieldErrorFromJson(json);

  Map<String, dynamic> toJson() => _$FieldErrorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
