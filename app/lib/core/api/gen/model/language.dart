//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 언어. 요청에서는 이 값만 받습니다(밖의 값은 400). 응답에서는 열린 enum이라 app은 모르는 값이면 기본 언어로 표시합니다.
enum Language {
  @JsonValue(r'ko')
  ko(r'ko'),
  @JsonValue(r'en')
  en(r'en'),
  @JsonValue(r'ja')
  ja(r'ja'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const Language(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
