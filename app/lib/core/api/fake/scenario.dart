import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 대역 서버 시나리오 하나: 앱이 보게 될 "오늘"과 네트워크 상태입니다.
///
/// 응답 fixture는 `fixtures/<id>/`에 있고, [lineage] 순서로 찾습니다.
final class Scenario {
  /// 시나리오를 만듭니다. [lineage]를 생략하면 자기 자신만 찾습니다.
  new({
    required this.id,
    required this.today,
    required this.timezone,
    this.offline = false,
    this.delay = Duration.zero,
    this.signedIn = false,
    List<String>? lineage,
  }) : lineage = List.unmodifiable(lineage ?? [id]);

  /// 시나리오 id. fixture 폴더 이름입니다.
  final String id;

  /// 시나리오의 오늘(프로필 시간대 기준 달력 날짜).
  final CalendarDate today;

  /// IANA 시간대 이름. 예: `Asia/Seoul`.
  final String timezone;

  /// true면 모든 요청이 연결 오류로 실패합니다.
  final bool offline;

  /// 응답 전에 기다리는 시간.
  final Duration delay;

  /// 앱을 켰을 때 로그인 상태인지. 토큰은 앱 시작 코드가 `refreshToken` fixture로 심습니다.
  final bool signedIn;

  /// fixture를 찾는 시나리오 id 순서: 자기 자신 → `extends` 부모 → 조상.
  final List<String> lineage;
}

/// `scenarios.json`이 잘못됐을 때의 오류.
final class ScenarioFormatException implements Exception {
  /// 원인을 설명하는 [message]를 담습니다.
  const new(this.message);

  /// 설명.
  final String message;

  @override
  String toString() => 'ScenarioFormatException: $message';
}

/// [bundle]의 `fixtures/scenarios.json`을 읽습니다.
Future<List<Scenario>> loadScenarios(AssetBundle bundle) async =>
    parseScenarios(await bundle.loadString('fixtures/scenarios.json'));

/// `scenarios.json` 본문을 해석합니다.
///
/// id 중복, 없는 부모, `extends` 순환은 [ScenarioFormatException]입니다.
List<Scenario> parseScenarios(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List<Object?>) {
    throw const ScenarioFormatException('scenarios.json은 배열이어야 합니다.');
  }
  final entries = <String, Map<String, Object?>>{};
  for (final item in decoded) {
    if (item is! Map<String, Object?> || item['id'] is! String) {
      throw const ScenarioFormatException('시나리오에는 문자열 id가 필요합니다.');
    }
    final id = item['id']! as String;
    if (entries.containsKey(id)) {
      throw ScenarioFormatException('시나리오 id가 겹칩니다: $id');
    }
    entries[id] = item;
  }
  return [
    for (final entry in entries.entries)
      _build(entry.key, entry.value, _lineageOf(entry.key, entries)),
  ];
}

List<String> _lineageOf(String id, Map<String, Map<String, Object?>> entries) {
  final lineage = <String>[];
  String? current = id;
  while (current != null) {
    if (lineage.contains(current)) {
      throw ScenarioFormatException(
        '시나리오 extends가 순환합니다: ${[...lineage, current].join(' -> ')}',
      );
    }
    final entry = entries[current];
    if (entry == null) {
      throw ScenarioFormatException(
        '없는 시나리오를 extends합니다: $current (${lineage.last}에서)',
      );
    }
    lineage.add(current);
    current = entry['extends'] as String?;
  }
  return lineage;
}

Scenario _build(String id, Map<String, Object?> json, List<String> lineage) {
  final today = json['today'];
  final timezone = json['timezone'];
  if (today is! String || timezone is! String) {
    throw ScenarioFormatException('$id: today와 timezone이 필요합니다.');
  }
  final CalendarDate date;
  try {
    date = CalendarDate.parse(today);
  } on FormatException {
    throw ScenarioFormatException('$id: today 형식이 잘못됐습니다: $today');
  }
  final delayMs = json['delayMs'];
  if (delayMs != null && (delayMs is! int || delayMs < 0)) {
    throw ScenarioFormatException('$id: delayMs는 0 이상의 정수여야 합니다: $delayMs');
  }
  final network = json['network'] ?? 'online';
  if (network != 'online' && network != 'offline') {
    throw ScenarioFormatException(
      '$id: network는 online 또는 offline이어야 합니다: $network',
    );
  }
  return Scenario(
    id: id,
    today: date,
    timezone: timezone,
    offline: network == 'offline',
    delay: Duration(milliseconds: (delayMs as int?) ?? 0),
    signedIn: json['signedIn'] == true,
    lineage: lineage,
  );
}
