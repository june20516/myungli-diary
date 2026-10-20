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
  test('fetch는 매번 server에 묻고, 연결이 안 되면 OfflineError입니다', () async {
    final s = _setUp();
    final first = await s.repository.fetch();
    expect(first.pillars.day.stem.value, 'gyeong');
    await s.repository.fetch();
    expect(s.server.requests, 2);

    s.server.offline = true;
    await expectLater(s.repository.fetch(), throwsA(isA<OfflineError>()));
  });

  test('store한 차트를 cached가 근거 열람 상태와 함께 돌려줍니다', () async {
    final s = _setUp();
    expect(await s.repository.cached(_key()), isNull);
    final fresh = await s.repository.fetch();
    await s.repository.store(_key(), fresh);

    final cached = await s.repository.cached(_key());
    expect(cached?.toJson(), fresh.toJson());
    expect(await s.cache.lockedKeys(CacheKind.chart), [_key()]);
    // 연도·언어가 다르면 다른 키라 캐시가 없습니다.
    expect(await s.repository.cached(_key(year: 2027)), isNull);
    expect(await s.repository.cached(_key(language: 'en')), isNull);
  });

  test('unlocked로 둔 차트는 locked 목록에 들지 않습니다', () async {
    final s = _setUp(scenario: 'evidence-unlocked');
    await s.repository.store(_key(), await s.repository.fetch());
    expect(await s.cache.lockedKeys(CacheKind.chart), isEmpty);
    expect(
      (await s.repository.cached(_key()))?.evidenceAccess,
      EvidenceAccess.unlocked,
    );
  });

  test('깨진 캐시는 없는 것으로 봅니다', () async {
    final s = _setUp();
    await s.cache.write(
      CacheKind.chart,
      _key(),
      '{"pillars": ',
      access: EvidenceAccess.locked,
    );
    expect(await s.repository.cached(_key()), isNull);
  });

  test('dropLocked는 locked로 둔 차트 캐시를 지웁니다', () async {
    final s = _setUp();
    await s.repository.store(_key(), await s.repository.fetch());
    expect(await s.cache.lockedKeys(CacheKind.chart), [_key()]);
    await s.repository.dropLocked();
    expect(await s.cache.lockedKeys(CacheKind.chart), isEmpty);
    expect(await s.repository.cached(_key()), isNull);
  });

  test('규칙 버전이 바뀐 응답을 받으면 이전 사주 기반 캐시가 지워집니다', () async {
    final s = _setUp();
    await s.repository.store(_key(), await s.repository.fetch());
    s.server.rulesetVersion = '2099.1.1';
    await s.repository.fetch();
    expect(await s.repository.cached(_key()), isNull);
  });
}
