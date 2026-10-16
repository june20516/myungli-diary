import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/glossary.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

const _notModified = 304;

/// 이름 사전을 ETag로 받아 계정 범위 캐시에 둡니다.
///
/// 캐시 키는 언어 코드, 저장 값은 `{"etag": …, "body": …}` JSON입니다.
final class GlossaryRepository {
  /// `api`로 받고 `cache`에 둡니다. 캐시 쓰기 실패는 `reporter`에 남깁니다.
  const new(this._api, this._cache, this._reporter);

  final DefaultApi _api;
  final CacheStore _cache;
  final CrashReporter _reporter;

  /// [language]의 사전을 돌려줍니다.
  ///
  /// 캐시가 있으면 `If-None-Match`로 확인하고, 304면 캐시를 씁니다.
  /// 연결이 안 되거나 시간이 초과되면 캐시를 쓰고, 캐시도 없으면 오류를 던집니다.
  Future<GlossaryNames> load(Language language) async {
    final cached = await _readCache(language);
    final Response<Glossary> response;
    try {
      response = await _api.getGlossary(
        lang: language,
        ifNoneMatch: cached?.etag,
        // 304는 오류가 아니라 "캐시를 쓰라"는 정상 응답입니다.
        validateStatus: (status) => status == 200 || status == _notModified,
      );
    } on DioException catch (e) {
      final error = appErrorFrom(e);
      if (cached != null && isConnectivityError(error)) {
        return cached.names;
      }
      throw error;
    }
    if (response.statusCode == _notModified) {
      if (cached == null) {
        throw UnexpectedError(StateError('캐시 없이 304를 받았습니다.'));
      }
      return cached.names;
    }
    final data = response.data;
    if (data == null) {
      throw UnexpectedError(StateError('빈 응답'));
    }
    // 쓰기 실패는 비치명입니다. 받은 사전은 그대로 쓰고 다음 200 응답이 다시 씁니다.
    await writeCacheOrReport(
      () => _cache.write(
        CacheKind.glossary,
        language.value,
        jsonEncode({
          'etag': response.headers.value('etag'),
          'body': data.toJson(),
        }),
        // 용어집은 근거 잠금과 무관해, 잠금 무효화 대상(`lockedKeys`)에 걸리지 않도록
        // `unlocked`로 둡니다. `CacheStore.write`의 필수 인자입니다.
        access: EvidenceAccess.unlocked,
      ),
      _reporter,
    );
    return _namesOf(data);
  }

  /// 캐시를 읽습니다. 없거나 깨졌으면(문법 오류·모양 불일치) null입니다.
  ///
  /// 깨진 항목은 "캐시 없음"으로 보고 다음 200 응답이 덮어써 회복합니다.
  Future<_CachedGlossary?> _readCache(Language language) async {
    final json = await _cache.read(CacheKind.glossary, language.value);
    if (json == null) {
      return null;
    }
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final body = Glossary.fromJson(map['body'] as Map<String, dynamic>);
      return _CachedGlossary(map['etag'] as String?, _namesOf(body));
    } on Object {
      return null;
    }
  }
}

GlossaryNames _namesOf(Glossary glossary) =>
    GlossaryNames(glossary.values, meanings: glossary.meanings);

final class _CachedGlossary {
  const new(this.etag, this.names);

  final String? etag;
  final GlossaryNames names;
}
