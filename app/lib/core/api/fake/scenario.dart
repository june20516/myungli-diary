import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 시나리오의 보상형 광고 대역 결과(`rewardedAd`).
enum ScenarioRewardedAd {
  /// 끝까지 봐서 보상을 받습니다.
  earned,

  /// 보상 전에 닫습니다.
  dismissed,

  /// 볼 수 있는 광고가 없습니다(불러오기가 null).
  unavailable,

  /// 광고를 표시하지 못합니다.
  failed,
}

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
    this.locale,
    this.rewardedAd = ScenarioRewardedAd.earned,
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

  /// 기기 로케일. null이면 기기(또는 테스트)가 정한 값을 그대로 씁니다.
  /// 한국 밖 기기(`en-US` 등)를 흉내 낼 때 씁니다.
  final Locale? locale;

  /// 보상형 광고 대역의 결과. 이어받지 않고 시나리오마다 정하며,
  /// 생략하면 [ScenarioRewardedAd.earned]입니다.
  final ScenarioRewardedAd rewardedAd;

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
    locale: _parseLocale(id, json['locale']),
    today: date,
    timezone: timezone,
    offline: network == 'offline',
    delay: Duration(milliseconds: (delayMs as int?) ?? 0),
    signedIn: json['signedIn'] == true,
    rewardedAd: _parseRewardedAd(id, json['rewardedAd']),
    lineage: lineage,
  );
}

/// `rewardedAd` 값을 읽습니다. 없으면 [ScenarioRewardedAd.earned]입니다.
ScenarioRewardedAd _parseRewardedAd(String id, Object? raw) {
  if (raw == null) {
    return ScenarioRewardedAd.earned;
  }
  for (final value in ScenarioRewardedAd.values) {
    if (value.name == raw) {
      return value;
    }
  }
  final names = ScenarioRewardedAd.values.map((v) => v.name).join(', ');
  throw ScenarioFormatException('$id: rewardedAd는 $names 중 하나여야 합니다: $raw');
}

/// `<언어>` 또는 `<언어>-<국가>`(예 `ko`, `en-US`) 형식의 로케일을 읽습니다. 없으면 null입니다.
Locale? _parseLocale(String id, Object? raw) {
  if (raw == null) {
    return null;
  }
  final match = raw is String
      ? RegExp(r'^([a-z]{2,3})(?:-([A-Z]{2}))?$').firstMatch(raw)
      : null;
  if (match == null) {
    throw ScenarioFormatException('$id: locale은 ko 또는 en-US 형식이어야 합니다: $raw');
  }
  return Locale(match.group(1)!, match.group(2));
}
