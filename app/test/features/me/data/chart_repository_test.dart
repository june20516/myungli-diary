import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/me/data/chart_repository.dart';

/// `/v1/chart`만 답하는 대역 서버. [scenario] fixture 본문으로 답합니다.
final class _ChartServer extends Interceptor {
  new(this.scenario);

  String scenario;

  /// 받은 요청 수.
  int requests = 0;

  /// true면 연결 오류로 끊습니다.
  bool offline = false;

  /// 응답의 규칙 버전을 바꿉니다. null이면 fixture 값 그대로입니다.
  String? rulesetVersion;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests++;
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: 'off'),
        true,
      );
      return;
    }
    final fixture = jsonDecode(
      File('fixtures/$scenario/getChart.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final body = fixture['body'] as Map<String, dynamic>;
    final version = rulesetVersion;
    if (version != null) {
      body['rulesetVersion'] = version;
    }
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/json'],
        }),
        data: body,
      ),
      true,
    );
  }
}

({ChartRepository repository, CacheStore cache, _ChartServer server}) _setUp({
  String scenario = 'member',
}) {
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(database.close);
  final cache = CacheStore(database, accountId: 'account-1');
  final server = _ChartServer(scenario);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..interceptors.add(server);
  return (
    repository: ChartRepository(DefaultApi(dio), cache, FakeCrashReporter()),
    cache: cache,
    server: server,
  );
}

String _key({int year = 2026, String language = 'ko'}) =>
    chartKey(fingerprint: 'fingerprint', language: language, year: year);

void main() {
  test('키가 있으면 한 번 받은 차트는 다시 묻지 않고, 오프라인이어도 캐시를 보입니다', () async {
    final s = _setUp();
    final first = await s.repository.chart(cacheKey: _key());
    expect(first.pillars.day.stem.value, 'gyeong');
    expect(s.server.requests, 1);

    s.server.offline = true;
    final cached = await s.repository.chart(cacheKey: _key());
    expect(cached.toJson(), first.toJson());
    expect(s.server.requests, 1);
  });

  test('연도·언어가 다르면 키가 달라 새로 받습니다', () async {
    final s = _setUp();
    await s.repository.chart(cacheKey: _key());
    await s.repository.chart(cacheKey: _key(year: 2027));
    await s.repository.chart(cacheKey: _key(language: 'en'));
    expect(s.server.requests, 3);
  });

  test('사본이 없으면(키 없음) 캐시를 읽지도 쓰지도 않고 매번 받습니다', () async {
    final s = _setUp();
    await s.repository.chart(cacheKey: null);
    await s.repository.chart(cacheKey: null);
    expect(s.server.requests, 2);
    expect(await s.cache.lockedKeys(CacheKind.chart), isEmpty);
  });

  test('skipCache면 캐시가 있어도 받고 새 값으로 씁니다', () async {
    final s = _setUp();
    await s.repository.chart(cacheKey: _key());
    s.server.scenario = 'evidence-unlocked';
    final fresh = await s.repository.chart(cacheKey: _key(), skipCache: true);
    expect(fresh.evidenceAccess, EvidenceAccess.unlocked);
    expect(s.server.requests, 2);
    final again = await s.repository.chart(cacheKey: _key());
    expect(again.evidenceAccess, EvidenceAccess.unlocked);
    expect(s.server.requests, 2);
  });

  test('locked로 받은 차트는 dropLocked 뒤 다시 받습니다', () async {
    final s = _setUp();
    await s.repository.chart(cacheKey: _key());
    expect(await s.cache.lockedKeys(CacheKind.chart), [_key()]);
    await s.repository.dropLocked();
    expect(await s.cache.lockedKeys(CacheKind.chart), isEmpty);
    await s.repository.chart(cacheKey: _key());
    expect(s.server.requests, 2);
  });

  test('규칙 버전이 바뀐 응답을 받으면 이전 사주 기반 캐시가 지워집니다', () async {
    final s = _setUp();
    await s.repository.chart(cacheKey: _key());
    s.server.rulesetVersion = '2099.1.1';
    await s.repository.chart(cacheKey: _key(year: 2027));
    s.server.offline = true;
    await expectLater(
      s.repository.chart(cacheKey: _key()),
      throwsA(isA<OfflineError>()),
    );
  });
}
