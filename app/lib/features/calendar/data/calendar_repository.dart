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
/// 받아 읽고 쓰기만 합니다. 캐시 먼저 보이기·server로 교체 흐름은 application이
/// `loadCacheFirst`로 짭니다(오늘 저장소와 같은 모양).
final class CalendarRepository {
  /// `api`로 받고 `cache`에 둡니다. 캐시 쓰기 실패는 `reporter`에 남깁니다.
  const new(this._api, this._cache, this._reporter);

  final DefaultApi _api;
  final CacheStore _cache;
  final CrashReporter _reporter;

  /// [month]의 달 길흉을 server에서 받습니다. 실패는 [AppError]입니다.
  ///
  /// * 받으면 캐시 키와 무관하게(사본이 없어도) 응답의 규칙 버전을 관찰합니다(규칙이 바뀌었으면
  ///   옛 사주 기반 캐시가 지워짐). 이 관찰은 [store]보다 먼저라 방금 받은 응답이 함께 지워지지
  ///   않습니다. 관찰 실패는 비치명입니다([writeCacheOrReport]).
  /// * 달력 밖 달([CalendarMonth.isSupported]가 false, 1900-01 등)은 묻지 않고 server가
  ///   줄 응답과 같은 422 `date.out_of_range` [ProblemError]로 끝냅니다(A44). 그날 시트·
  ///   일정 편집이 1900-01-31을 열어도 늘 거절될 요청을 보내지 않습니다.
  Future<Calendar> fetch(CalendarMonth month) async {
    if (!month.isSupported) {
      throw outOfRangeProblem;
    }
    final fresh = await _fetch(month);
    await writeCacheOrReport(
      () => _cache.observeRulesetVersion(fresh.rulesetVersion),
      _reporter,
    );
    return fresh;
  }

  /// [key]의 캐시. 없거나 깨졌으면(문법 오류·모양 불일치) null이고, 다음 응답이 덮어써
  /// 회복합니다.
  ///
  /// 캐시는 먼저 보이기용입니다. 근거 열람 권한(보상형 해제는 그날 자정까지, D60)과 문장은
  /// 매 진입 [fetch]로 확인합니다(A32·A56). `getCalendar`에는 ETag가 없어 조건부 요청은 없습니다.
  Future<Calendar?> cached(String key) async {
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

  /// [fetch]로 받은 [calendar]를 근거 열람 상태와 함께 [key]에 둡니다.
  Future<void> store(String key, Calendar calendar) => _cache.write(
    CacheKind.calendar,
    key,
    jsonEncode(calendar.toJson()),
    access: calendar.evidenceAccess,
    rulesetVersion: calendar.rulesetVersion,
  );

  /// `locked`로 받아 둔 달 캐시를 지웁니다. 근거 열람 권한이 생긴 뒤 부릅니다(A32).
  Future<void> dropLocked() async {
    final keys = await _cache.lockedKeys(CacheKind.calendar);
    await _cache.remove(CacheKind.calendar, keys);
  }

  /// 달력 밖 달을 물었을 때의 오류. server `getCalendar`의 범위 밖 응답과 같은 모양입니다.
  static const ProblemError outOfRangeProblem = ProblemError(
    code: outOfRangeCode,
    status: 422,
    fieldErrors: [],
    traceId: '',
  );

  /// 지원 범위 밖 날짜의 problem code(D41).
  static const String outOfRangeCode = 'date.out_of_range';

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
}
