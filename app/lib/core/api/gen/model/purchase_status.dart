//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 구매 상태. 열린 enum이라 app은 모르는 값이 와도 그 항목을 기본 표시로 보입니다. 기간 상품은 `active`·`pending`·`expired`·`refunded`, 기간 없는 상품은 `owned`·`refunded`입니다. 합치기 전에 끝난 다른 유저 계정의 구매는 현재 유저 계정에 구간이 없어 `expired`이고 `period`가 없습니다.
enum PurchaseStatus {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'pending')
  pending(r'pending'),
  @JsonValue(r'expired')
  expired(r'expired'),
  @JsonValue(r'refunded')
  refunded(r'refunded'),
  @JsonValue(r'owned')
  owned(r'owned'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PurchaseStatus(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
