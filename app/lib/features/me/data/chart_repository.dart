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
/// 읽고 쓰기만 합니다. 캐시 먼저 보이기·server로 교체 흐름은 application이 `loadCacheFirst`로
/// 짭니다(오늘 저장소와 같은 모양).
final class ChartRepository {
  /// `api`로 받고 `cache`에 둡니다. 캐시 쓰기 실패는 `reporter`에 남깁니다.
  const new(this._api, this._cache, this._reporter);

  final DefaultApi _api;
  final CacheStore _cache;
  final CrashReporter _reporter;

  /// 차트를 server에서 받습니다. 실패는 [AppError]입니다.
  ///
  /// 받으면 캐시 키와 무관하게(사본이 없어도) 응답의 규칙 버전을 관찰합니다. 규칙이 바뀌었으면
  /// 사주 기반 캐시가 지워집니다. 이 관찰은 [store]보다 먼저라 방금 받은 응답이 함께 지워지지
  /// 않습니다. 관찰 실패는 비치명입니다([writeCacheOrReport]).
  Future<Chart> fetch() async {
    final fresh = await _fetch();
    await writeCacheOrReport(
      () => _cache.observeRulesetVersion(fresh.rulesetVersion),
      _reporter,
    );
    return fresh;
  }

  /// [key]의 캐시를 읽습니다. 없거나 깨졌으면 null이고, 다음 응답이 덮어써 회복합니다.
  ///
  /// 캐시는 먼저 보이기용입니다. 근거 열람 권한(보상형 해제는 그날 자정까지, D60)과 문장은
  /// 매 진입 [fetch]로 확인합니다(A56).
  Future<Chart?> cached(String key) async {
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

  /// [fetch]로 받은 [chart]를 근거 열람 상태와 함께 [key]에 둡니다.
  Future<void> store(String key, Chart chart) => _cache.write(
    CacheKind.chart,
    key,
    jsonEncode(chart.toJson()),
    access: chart.evidenceAccess,
    rulesetVersion: chart.rulesetVersion,
  );

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
}

/// 차트가 근거까지 열려 있는지.
bool isChartUnlocked(Chart chart) =>
    chart.evidenceAccess == EvidenceAccess.unlocked;
