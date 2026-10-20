import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';

/// 나의 사주(`getChart`)와 사주 기반 영구 캐시(결정 A56, spec §4.4).
///
/// 캐시 키는 `chartKey(지문, 언어, 연도)`이고 application이 정합니다. 이 저장소는 키를 받아
/// 읽고 쓰기만 합니다. 규칙은 달력 저장소(A32)와 같습니다.
final class ChartRepository {
  /// `api`로 받고 `cache`에 둡니다. 캐시 쓰기 실패는 `reporter`에 남깁니다.
  const new(this._api, this._cache, this._reporter);

  final DefaultApi _api;
  final CacheStore _cache;
  final CrashReporter _reporter;

  /// 차트. 실패는 [AppError]입니다.
  ///
  /// * [cacheKey]가 있고 캐시가 있으면 요청하지 않고 캐시를 돌려줍니다. [skipCache]면 캐시를
  ///   읽지 않고 받습니다(잠금 해제 뒤 다시 받기, 오류의 다시 시도).
  /// * 받은 응답의 규칙 버전을 먼저 관찰하고 근거 열람 상태와 함께 씁니다.
  /// * [cacheKey]가 null(프로필 사본 없음)이면 캐시를 읽지도 쓰지도 않습니다(A24와 같음).
  ///
  /// 관찰·쓰기 실패는 비치명입니다([writeCacheOrReport]).
  Future<Chart> chart({
    required String? cacheKey,
    bool skipCache = false,
  }) async {
    if (cacheKey != null && !skipCache) {
      final cached = await _cached(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    final fresh = await _fetch();
    await writeCacheOrReport(
      () => _cache.observeRulesetVersion(fresh.rulesetVersion),
      _reporter,
    );
    if (cacheKey != null) {
      await writeCacheOrReport(
        () => _cache.write(
          CacheKind.chart,
          cacheKey,
          jsonEncode(fresh.toJson()),
          access: fresh.evidenceAccess,
          rulesetVersion: fresh.rulesetVersion,
        ),
        _reporter,
      );
    }
    return fresh;
  }

  /// `locked`로 받아 둔 차트 캐시를 지웁니다. 근거 열람 권한이 생긴 뒤 부릅니다(A56).
  Future<void> dropLocked() async {
    final keys = await _cache.lockedKeys(CacheKind.chart);
    await _cache.remove(CacheKind.chart, keys);
  }

  Future<Chart> _fetch() async {
    final Chart? data;
    try {
      data = (await _api.getChart()).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (data == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    return data;
  }

  /// [key]의 캐시. 없거나 깨졌으면 null이고, 다음 응답이 덮어써 회복합니다.
  Future<Chart?> _cached(String key) async {
    final json = await _cache.read(CacheKind.chart, key);
    if (json == null) {
      return null;
    }
    try {
      return Chart.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}

/// 차트가 근거까지 열려 있는지.
bool isChartUnlocked(Chart chart) =>
    chart.evidenceAccess == EvidenceAccess.unlocked;
