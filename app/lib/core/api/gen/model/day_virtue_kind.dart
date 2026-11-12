//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 택일 덕일 종류입니다. `cheondeok_day` 천덕일, `woldeok_day` 월덕일. 원국의 천덕귀인, 월덕귀인(`ShinsalKind`의 `cheondeok`, `woldeok`)과 다른 정보입니다. 열린 enum입니다.
enum DayVirtueKind {
  @JsonValue(r'cheondeok_day')
  cheondeokDay(r'cheondeok_day'),
  @JsonValue(r'woldeok_day')
  woldeokDay(r'woldeok_day'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DayVirtueKind(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
