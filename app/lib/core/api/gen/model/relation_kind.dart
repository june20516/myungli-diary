//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum RelationKind {
  @JsonValue(r'stem_hap')
  stemHap(r'stem_hap'),
  @JsonValue(r'branch_hap')
  branchHap(r'branch_hap'),
  @JsonValue(r'chung')
  chung(r'chung'),
  @JsonValue(r'hyeong')
  hyeong(r'hyeong'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RelationKind(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
