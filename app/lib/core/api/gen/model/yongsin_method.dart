//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 용신을 고른 방법. 열린 enum입니다(통관·병약·격국 용신이 더해질 수 있음). app은 모르는 값이면 방법 표시를 건너뜁니다.
enum YongsinMethod {
  @JsonValue(r'johu')
  johu(r'johu'),
  @JsonValue(r'johu_neutral')
  johuNeutral(r'johu_neutral'),
  @JsonValue(r'eokbu')
  eokbu(r'eokbu'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const YongsinMethod(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
