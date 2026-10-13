//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 근거 열람 권한 상태(D60). 권한이 없으면 `locked`이고, evidence 깊이의 해석(판정 근거, 원전, 원국 개인 해석, 용신 근거)을 응답에서 뺍니다. surface·explain과 표 데이터는 잠그지 않습니다. 근거가 원래 없는 것과 잠겨서 빠진 것을 이 값으로 구분합니다.
enum EvidenceAccess {
  @JsonValue(r'unlocked')
  unlocked(r'unlocked'),
  @JsonValue(r'locked')
  locked(r'locked');

  const EvidenceAccess(this.value);

  final String value;

  @override
  String toString() => value;
}
