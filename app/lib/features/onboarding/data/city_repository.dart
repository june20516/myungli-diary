import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show StringCharacters, immutable;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';

/// 계약 `q`의 최대 길이(1~50자).
const int cityQueryMaxLength = 50;

/// 응답 `ETag`와 그때 받은 목록.
@immutable
class _CachedCities {
  const new(this.etag, this.items);

  final String etag;
  final List<City> items;
}

/// 도시 검색(`listCities`, D29). 로그인 없이 부릅니다.
///
/// 같은 질의(검색어·언어)는 이전 응답의 `ETag`를 `If-None-Match`로 보내고, 304면 이전
/// 목록을 그대로 돌려줍니다(참조 데이터, spec §4.4). 목록은 메모리에만 둡니다.
final class CityRepository {
  /// 생성 REST 클라이언트로 요청합니다.
  new(this._api);

  final DefaultApi _api;
  final Map<String, _CachedCities> _cache = {};

  /// [query]에 맞는 도시를 [language]로 받습니다.
  ///
  /// 한 번에 20개(계약 기본값)를 받습니다. 앞뒤 공백을 지우고
  /// [cityQueryMaxLength]자를 넘으면 자릅니다. 비면 요청하지 않고 빈
  /// 목록입니다. 실패는 [AppError]입니다.
  Future<List<City>> search(String query, {required Language language}) async {
    final q = query.trim().characters.take(cityQueryMaxLength).toString();
    if (q.isEmpty) return const [];
    final key = '${language.value}\n$q';
    final cached = _cache[key];
    try {
      final response = await _api.listCities(
        q: q,
        lang: language,
        ifNoneMatch: cached?.etag,
      );
      if (response.statusCode == 304 && cached != null) return cached.items;
      final data = response.data;
      if (data == null) throw UnexpectedError(StateError('빈 응답'));
      final etag = response.headers.value('etag');
      if (etag != null) {
        _cache[key] = _CachedCities(etag, data.items);
      } else {
        _cache.remove(key);
      }
      return data.items;
    } on DioException catch (e) {
      // 기본 설정의 Dio는 304를 예외로 올립니다.
      if (e.response?.statusCode == 304 && cached != null) return cached.items;
      throw appErrorFrom(e);
    }
  }
}
