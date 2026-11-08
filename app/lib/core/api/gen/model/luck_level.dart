//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 달력 하루의 길흉 수준입니다. 점수 3 이상 `very_good`(아주 잘 풀리는 날), 2 `good`, -2 이하 `caution`, 그 밖 `neutral`입니다. 닫힌 enum입니다. `very_good`은 1.5.0에서 더했고, 출시 전이라 v1의 닫힌 enum에 값을 더한 예외입니다(server 결정 S138).
enum LuckLevel {
  @JsonValue(r'very_good')
  veryGood(r'very_good'),
  @JsonValue(r'good')
  good(r'good'),
  @JsonValue(r'neutral')
  neutral(r'neutral'),
  @JsonValue(r'caution')
  caution(r'caution');

  const LuckLevel(this.value);

  final String value;

  @override
  String toString() => value;
}
