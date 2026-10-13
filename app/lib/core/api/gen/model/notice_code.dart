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
  focusTimeFallback(r'focus_time_fallback');

  const NoticeCode(this.value);

  final String value;

  @override
  String toString() => value;
}
