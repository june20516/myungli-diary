//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 로그인 제공자. 요청(`{provider}` 경로)에서는 이 값만 받습니다(밖의 값은 400). 응답에서는 열린 enum이라 app은 모르는 값을 건너뜁니다.
enum LoginProvider {
  @JsonValue(r'kakao')
  kakao(r'kakao'),
  @JsonValue(r'apple')
  apple(r'apple'),
  @JsonValue(r'line')
  line(r'line'),
  @JsonValue(r'google')
  google(r'google'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const LoginProvider(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
