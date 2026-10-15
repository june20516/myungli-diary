import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';

/// 반응을 남긴 슬롯의 `reaction` 값(계약 enum).
const _likeReaction = 'like';

/// 그날 응답(`getDaily`)과 그날 캐시(결정 A24).
///
/// 캐시 키는 `dailyKey(지문, 언어, 날짜)`이고 controller가 정합니다. 이 저장소는 키를
/// 받아 읽고 쓰기만 합니다.
final class DailyRepository {
  /// `api`로 받고 `cache`에 둡니다. 캐시 쓰기 실패는 `reporter`에 남깁니다.
  const new(this._api, this._cache, this._reporter);

  final DefaultApi _api;
  final CacheStore _cache;
  final CrashReporter _reporter;

  /// [date]의 응답을 server에서 받습니다. 실패는 [AppError]입니다.
  ///
  /// 받으면 캐시 키와 무관하게(사본이 없어도) 응답의 규칙 버전을 관찰합니다. 규칙이
  /// 바뀌었으면 사주 기반 캐시가 지워집니다(spec §4.4 "버리는 때 2"). 이 관찰은 [store]보다
  /// 먼저라 방금 받은 응답이 함께 지워지지 않습니다. 관찰 실패는 비치명입니다
  /// ([writeCacheOrReport]).
  Future<Daily> fetch(CalendarDate date) async {
    final Daily? data;
    try {
      data = (await _api.getDaily(date: date.toIso())).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (data == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    await writeCacheOrReport(
      () => _cache.observeRulesetVersion(data!.rulesetVersion),
      _reporter,
    );
    return data;
  }

  /// [key]의 캐시를 읽습니다. 없거나 깨졌으면(문법 오류·모양 불일치) null입니다.
  ///
  /// 깨진 항목은 "캐시 없음"으로 보고 다음 응답이 덮어써 회복합니다.
  Future<Daily?> cached(String key) async {
    final json = await _cache.read(CacheKind.daily, key);
    if (json == null) {
      return null;
    }
    try {
      return Daily.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// [fetch]로 받은 [daily]를 [key]에 둡니다.
  ///
  /// 규칙 버전 관찰은 [fetch]가 이미 했습니다(관찰 → 쓰기 순서).
  Future<void> store(String key, Daily daily) => _write(key, daily);

  /// [key] 캐시에서 `slot`이 [slot]인 모든 문장의 `reaction`을 [liked]면 `like`로 넣고,
  /// 아니면 지웁니다(결정 A25: 반응이 성공한 뒤 캐시도 맞춤).
  ///
  /// 캐시가 없거나 깨졌으면 고칠 것이 없으므로 아무것도 하지 않습니다.
  /// 새 응답이 아니므로 규칙 버전은 관찰하지 않습니다.
  Future<void> patchCachedReaction(
    String key, {
    required String slot,
    required bool liked,
  }) async {
    final json = await _cache.read(CacheKind.daily, key);
    if (json == null) {
      return;
    }
    final Daily patched;
    try {
      final decoded = jsonDecode(json);
      _setReaction(decoded, slot: slot, liked: liked);
      patched = Daily.fromJson(decoded as Map<String, dynamic>);
    } on Object {
      return;
    }
    await _write(key, patched);
  }

  Future<void> _write(String key, Daily daily) => _cache.write(
    CacheKind.daily,
    key,
    jsonEncode(daily.toJson()),
    access: daily.evidenceAccess,
    rulesetVersion: daily.rulesetVersion,
  );
}

/// JSON 트리를 돌며 `slot`이 [slot]인 객체의 `reaction`을 바꿉니다.
///
/// 슬롯 문장(`SlotText`)이 총운·가이드·카드 어디에 있든 위치를 몰라도 되게 트리 전체를 봅니다.
void _setReaction(Object? node, {required String slot, required bool liked}) {
  if (node is Map<String, dynamic>) {
    if (node['slot'] == slot) {
      if (liked) {
        node['reaction'] = _likeReaction;
      } else {
        node.remove('reaction');
      }
    }
    for (final child in node.values) {
      _setReaction(child, slot: slot, liked: liked);
    }
  } else if (node is List<dynamic>) {
    for (final child in node) {
      _setReaction(child, slot: slot, liked: liked);
    }
  }
}
