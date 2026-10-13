//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum Position {
  @JsonValue(r'year_stem')
  yearStem(r'year_stem'),
  @JsonValue(r'year_branch')
  yearBranch(r'year_branch'),
  @JsonValue(r'month_stem')
  monthStem(r'month_stem'),
  @JsonValue(r'month_branch')
  monthBranch(r'month_branch'),
  @JsonValue(r'day_stem')
  dayStem(r'day_stem'),
  @JsonValue(r'day_branch')
  dayBranch(r'day_branch'),
  @JsonValue(r'hour_stem')
  hourStem(r'hour_stem'),
  @JsonValue(r'hour_branch')
  hourBranch(r'hour_branch');

  const Position(this.value);

  final String value;

  @override
  String toString() => value;
}
