import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';

/// 사주 지문. 사주 기반 캐시 키의 일부입니다.
///
/// 입력은 출생 정보 전체(`Profile.birth`)와 현재 시간대뿐입니다.
/// 호칭·언어·알림은 사주를 바꾸지 않으므로 넣지 않습니다.
/// 키를 정렬한 JSON을 SHA-256으로 해시해 hex로 돌려줍니다.
String sajuFingerprint(Profile profile) {
  final canonical = _canonicalJson(<String, Object?>{
    'birth': profile.birth.toJson(),
    'currentTimezone': profile.currentTimezone,
  });
  return sha256.convert(utf8.encode(canonical)).toString();
}

/// 중첩 맵까지 키를 정렬해 같은 값이면 같은 문자열이 되게 합니다.
String _canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List) {
    return value.map(_sorted).toList();
  }
  return value;
}
