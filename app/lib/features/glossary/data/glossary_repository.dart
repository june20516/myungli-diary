import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/glossary.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';

const _notModified = 304;

/// 값 이름 사전. 이름 조회는 모두 여기를 거칩니다(오늘·달력·일기 태그·나의 사주).
final class GlossaryNames {
  /// 범주 → (값 → 이름).
  const new(this.values);

  /// 범주 → (값 → 이름).
  final Map<String, Map<String, String>> values;

  /// `<범주>.<값>` 형태의 [termId]에 해당하는 이름. 모르면 null입니다.
  ///
  /// 첫 `.`에서 나누므로 값에 `.`이 들어가도(`ten_god_rush.bigyeop`) 됩니다.
  /// 태그는 `tag.<키>`입니다.
  String? nameOf(String termId) {
    final dot = termId.indexOf('.');
    if (dot <= 0) {
      return null;
    }
    return valueName(termId.substring(0, dot), termId.substring(dot + 1));
  }

  /// [category]의 [value] 이름. 모르면 null입니다.
  String? valueName(String category, String value) => values[category]?[value];
}

/// 이름 사전을 ETag로 받아 계정 범위 캐시에 둡니다.
///
/// 캐시 키는 언어 코드, 저장 값은 `{"etag": …, "body": …}` JSON입니다.
final class GlossaryRepository {
  /// `api`로 받고 `cache`에 둡니다.
  const new(this._api, this._cache);

  final DefaultApi _api;
  final CacheStore _cache;

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
      if (cached != null && (error is OfflineError || error is TimeoutError)) {
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
    await _cache.write(
      CacheKind.glossary,
      language.value,
      jsonEncode({
        'etag': response.headers.value('etag'),
        'body': data.toJson(),
      }),
      // 근거 잠금과 무관한 값입니다. `CacheStore.write`의 필수 인자라 채웁니다.
      access: EvidenceAccess.unlocked,
    );
    return GlossaryNames(data.values);
  }

  Future<_CachedGlossary?> _readCache(Language language) async {
    final json = await _cache.read(CacheKind.glossary, language.value);
    if (json == null) {
      return null;
    }
    final map = jsonDecode(json) as Map<String, dynamic>;
    final body = Glossary.fromJson(map['body'] as Map<String, dynamic>);
    return _CachedGlossary(map['etag'] as String?, GlossaryNames(body.values));
  }
}

final class _CachedGlossary {
  const new(this.etag, this.names);

  final String? etag;
  final GlossaryNames names;
}
