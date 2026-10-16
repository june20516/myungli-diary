import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';

/// 달 길흉(`getCalendar`)과 사주 기반 영구 캐시(결정 A32, spec §4.4).
///
/// 캐시 키는 `calendarKey(지문, 언어, 연, 월)`이고 application이 정합니다. 이 저장소는 키를
/// 받아 읽고 쓰기만 합니다.
final class CalendarRepository {
  /// `api`로 받고 `cache`에 둡니다. 캐시 쓰기 실패는 `reporter`에 남깁니다.
  const new(this._api, this._cache, this._reporter);

  final DefaultApi _api;
  final CacheStore _cache;
  final CrashReporter _reporter;

  /// [month]의 달 길흉. 실패는 [AppError]입니다.
  ///
  /// * [cacheKey]가 있고 캐시가 있으면 요청하지 않고 캐시를 돌려줍니다. 한 번 받은 달은
  ///   사주·규칙·잠금이 바뀌어 캐시가 지워질 때까지 다시 받지 않습니다(`getCalendar`에는
  ///   ETag가 없습니다). 오프라인이어도 캐시가 있으면 그대로 보입니다.
  /// * 캐시가 없거나 깨졌으면 받습니다. 받은 응답의 규칙 버전을 먼저 관찰하고(규칙이
  ///   바뀌었으면 옛 사주 기반 캐시가 지워짐) 그 뒤에 근거 열람 상태와 함께 씁니다.
  /// * [cacheKey]가 null(프로필 사본 없음)이면 캐시를 읽지도 쓰지도 않고 매번 받습니다
  ///   (A24와 같음). 규칙 버전 관찰은 키와 무관하게 합니다.
  ///
  /// 관찰·쓰기 실패는 비치명입니다([writeCacheOrReport]).
  Future<Calendar> month(
    CalendarMonth month, {
    required String? cacheKey,
  }) async {
    if (cacheKey != null) {
      final cached = await _cached(cacheKey);
      if (cached != null) {
        return cached;
      }
    }
    final fresh = await _fetch(month);
    await writeCacheOrReport(
      () => _cache.observeRulesetVersion(fresh.rulesetVersion),
      _reporter,
    );
    if (cacheKey != null) {
      await writeCacheOrReport(
        () => _cache.write(
          CacheKind.calendar,
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

  /// `locked`로 받아 둔 달 캐시를 지웁니다. 근거 열람 권한이 생긴 뒤 부릅니다(A32).
  Future<void> dropLocked() async {
    final keys = await _cache.lockedKeys(CacheKind.calendar);
    await _cache.remove(CacheKind.calendar, keys);
  }

  Future<Calendar> _fetch(CalendarMonth month) async {
    final Calendar? data;
    try {
      data = (await _api.getCalendar(
        year: month.year,
        month: month.month,
      )).data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
    if (data == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    return data;
  }

  /// [key]의 캐시. 없거나 깨졌으면(문법 오류·모양 불일치) null이고, 다음 응답이 덮어써
  /// 회복합니다.
  Future<Calendar?> _cached(String key) async {
    final json = await _cache.read(CacheKind.calendar, key);
    if (json == null) {
      return null;
    }
    try {
      return Calendar.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}
