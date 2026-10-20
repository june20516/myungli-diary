//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum NoticeCode {
  @JsonValue(r'ambiguous_local_time')
  ambiguousLocalTime(r'ambiguous_local_time'),
  @JsonValue(r'nonexistent_local_time')
  nonexistentLocalTime(r'nonexistent_local_time'),
  @JsonValue(r'zi_hour_next_day')
  ziHourNextDay(r'zi_hour_next_day'),
  @JsonValue(r'time_unknown')
  timeUnknown(r'time_unknown'),
  @JsonValue(r'near_solar_term')
  nearSolarTerm(r'near_solar_term'),
  @JsonValue(r'dayun_start_approximate')
  dayunStartApproximate(r'dayun_start_approximate'),
  @JsonValue(r'focus_time_fallback')
  focusTimeFallback(r'focus_time_fallback'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const NoticeCode(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
