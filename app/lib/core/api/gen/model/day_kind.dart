//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum DayKind {
  @JsonValue(r'gwiin_day')
  gwiinDay(r'gwiin_day'),
  @JsonValue(r'yongsin_day')
  yongsinDay(r'yongsin_day'),
  @JsonValue(r'gisin_day')
  gisinDay(r'gisin_day'),
  @JsonValue(r'ordinary_day')
  ordinaryDay(r'ordinary_day');

  const DayKind(this.value);

  final String value;

  @override
  String toString() => value;
}
