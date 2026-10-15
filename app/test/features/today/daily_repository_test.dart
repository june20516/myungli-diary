import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/today/data/daily_repository.dart';

/// member 시나리오의 `getDaily` 응답 본문. fixture와 테스트가 같은 값을 보게 합니다.
Map<String, dynamic> memberDailyJson() {
  final fixture = jsonDecode(
    File('fixtures/member/getDaily.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return fixture['body'] as Map<String, dynamic>;
}

/// 실행한 쓰기 SQL을 순서대로 남깁니다.
final class _StatementLog extends QueryInterceptor {
  final statements = <String>[];

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    return super.runDelete(executor, statement, args);
  }
}

/// `/v1/daily/{date}` 요청 경로를 남기고, [offline]이면 연결 오류로, 아니면 [body]로 답합니다.
final class _DailyServer extends Interceptor {
  final paths = <String>[];
  bool offline = false;
  final Map<String, dynamic> body = memberDailyJson();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    paths.add(options.path);
    if (offline) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
        true,
      );
      return;
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

({
  DailyRepository repository,
  CacheStore cache,
  _DailyServer server,
  _StatementLog log,
})
_setUp() {
  final log = _StatementLog();
  final database = AppDatabase.forExecutor(
    NativeDatabase.memory().interceptWith(log),
  );
  addTearDown(database.close);
  final cache = CacheStore(database, accountId: 'account-1');
  final server = _DailyServer();
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..interceptors.add(server);
  return (
    repository: DailyRepository(DefaultApi(dio), cache),
    cache: cache,
    server: server,
    log: log,
  );
}

const _key = 'fingerprint|ko|2026-10-13';

Map<String, dynamic> _storedJson(String? raw) =>
    jsonDecode(raw!) as Map<String, dynamic>;

void main() {
  group('fetch', () {
    test('그날 경로로 받는다', () async {
      final s = _setUp();

      final daily = await s.repository.fetch(CalendarDate(2026, 10, 13));

      expect(s.server.paths.single, '/v1/daily/2026-10-13');
      expect(daily.rulesetVersion, 'r1');
    });

    test('연결 오류는 OfflineError', () async {
      final s = _setUp();
      s.server.offline = true;

      await expectLater(
        s.repository.fetch(CalendarDate(2026, 10, 13)),
        throwsA(isA<OfflineError>()),
      );
    });
  });

  group('cached', () {
    test('없으면 null', () async {
      final s = _setUp();

      expect(await s.repository.cached(_key), isNull);
    });

    test('store한 응답을 그대로 읽는다', () async {
      final s = _setUp();
      final daily = Daily.fromJson(memberDailyJson());

      await s.repository.store(_key, daily);

      expect((await s.repository.cached(_key))!.toJson(), daily.toJson());
    });

    test('깨진 JSON이면 캐시 없음(null)으로 회복한다', () async {
      final s = _setUp();
      await s.cache.write(
        CacheKind.daily,
        _key,
        '{"date": 1',
        access: EvidenceAccess.locked,
      );

      expect(await s.repository.cached(_key), isNull);
    });

    test('모양이 다른 JSON이어도 null', () async {
      final s = _setUp();
      await s.cache.write(
        CacheKind.daily,
        _key,
        '{"date": "2026-10-13"}',
        access: EvidenceAccess.locked,
      );

      expect(await s.repository.cached(_key), isNull);
    });
  });

  group('store', () {
    test('store는 rulesetVersion 관찰 뒤에 쓴다', () async {
      final s = _setUp();
      // 이전 규칙(r0)으로 받은 달력 캐시가 있습니다.
      await s.cache.observeRulesetVersion('r0');
      await s.cache.write(
        CacheKind.calendar,
        'fingerprint|ko|2026-10',
        '{}',
        access: EvidenceAccess.locked,
        rulesetVersion: 'r0',
      );
      s.log.statements.clear();

      await s.repository.store(_key, Daily.fromJson(memberDailyJson()));

      // 규칙이 바뀐(r1) 응답을 저장해도 그날 캐시는 남고, 사주 기반 캐시는 지워집니다.
      expect(await s.cache.read(CacheKind.daily, _key), isNotNull);
      expect(
        await s.cache.read(CacheKind.calendar, 'fingerprint|ko|2026-10'),
        isNull,
      );
      // 관찰(기준값 쓰기)이 그날 캐시 쓰기보다 먼저입니다.
      final flagWrite = s.log.statements.indexWhere(
        (sql) => sql.contains('device_flags'),
      );
      final dailyWrite = s.log.statements.indexWhere(
        (sql) => sql.startsWith('INSERT') && sql.contains('cached_responses'),
      );
      expect(flagWrite, isNonNegative);
      expect(dailyWrite, greaterThan(flagWrite));
    });

    test('근거 잠금과 규칙 버전을 행에 남긴다', () async {
      final s = _setUp();

      await s.repository.store(_key, Daily.fromJson(memberDailyJson()));

      expect(await s.cache.lockedKeys(CacheKind.daily), [_key]);
    });
  });

  group('patchCachedReaction', () {
    test('patchCachedReaction은 그 슬롯의 reaction만 바꾼다', () async {
      final s = _setUp();
      await s.repository.store(_key, Daily.fromJson(memberDailyJson()));

      await s.repository.patchCachedReaction(
        _key,
        slot: 'daily.fortune.head',
        liked: true,
      );

      var stored = _storedJson(await s.cache.read(CacheKind.daily, _key));
      var fortune = stored['fortune'] as Map<String, dynamic>;
      expect((fortune['head'] as Map<String, dynamic>)['reaction'], 'like');
      expect(
        fortune['tag'] as Map<String, dynamic>,
        isNot(contains('reaction')),
      );
      expect(
        stored['guide'] as Map<String, dynamic>,
        isNot(contains('reaction')),
      );
      // 잠금 상태는 그대로라 잠금 해제 뒤 다시 받기 대상에 남습니다.
      expect(await s.cache.lockedKeys(CacheKind.daily), [_key]);

      await s.repository.patchCachedReaction(
        _key,
        slot: 'daily.fortune.head',
        liked: false,
      );

      stored = _storedJson(await s.cache.read(CacheKind.daily, _key));
      fortune = stored['fortune'] as Map<String, dynamic>;
      expect(
        fortune['head'] as Map<String, dynamic>,
        isNot(contains('reaction')),
      );
      expect((await s.repository.cached(_key))!.fortune.head.reaction, isNull);
    });

    test('카드 안의 슬롯도 고친다', () async {
      final s = _setUp();
      await s.repository.store(_key, Daily.fromJson(memberDailyJson()));

      await s.repository.patchCachedReaction(
        _key,
        slot: 'daily.color',
        liked: true,
      );

      final daily = (await s.repository.cached(_key))!;
      expect(daily.cards.color.text.reaction?.value, 'like');
      expect(daily.fortune.head.reaction, isNull);
    });

    test('캐시가 없거나 깨졌으면 아무것도 하지 않는다', () async {
      final s = _setUp();

      await s.repository.patchCachedReaction(
        _key,
        slot: 'daily.fortune.head',
        liked: true,
      );
      expect(await s.cache.read(CacheKind.daily, _key), isNull);

      await s.cache.write(
        CacheKind.daily,
        _key,
        '{"date": 1',
        access: EvidenceAccess.locked,
      );
      await s.repository.patchCachedReaction(
        _key,
        slot: 'daily.fortune.head',
        liked: true,
      );
      expect(await s.cache.read(CacheKind.daily, _key), '{"date": 1');
    });
  });
}
