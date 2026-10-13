//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum LuckLevel {
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
