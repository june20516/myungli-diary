//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 합친 뒤 쓸 프로필. `current`는 현재 유저 계정(A)의 것, `other`는 합치는 다른 유저 계정(B)의 것입니다.
enum MergeProfile {
  @JsonValue(r'current')
  current(r'current'),
  @JsonValue(r'other')
  other(r'other');

  const MergeProfile(this.value);

  final String value;

  @override
  String toString() => value;
}
