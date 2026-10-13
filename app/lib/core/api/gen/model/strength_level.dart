//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum StrengthLevel {
  @JsonValue(r'very_weak')
  veryWeak(r'very_weak'),
  @JsonValue(r'weak')
  weak(r'weak'),
  @JsonValue(r'neutral')
  neutral(r'neutral'),
  @JsonValue(r'strong')
  strong(r'strong'),
  @JsonValue(r'very_strong')
  veryStrong(r'very_strong');

  const StrengthLevel(this.value);

  final String value;

  @override
  String toString() => value;
}
