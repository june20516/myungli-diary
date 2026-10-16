import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/calendar/data/calendar_repository.dart';

/// member 시나리오의 `getCalendar` 응답 본문(fixture와 같은 값).
Map<String, dynamic> _calendarJson(CalendarMonth month) {
  final fixture = jsonDecode(
    File('fixtures/member/getCalendar__${month.year}-${month.month}.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  return fixture['body'] as Map<String, dynamic>;
}

/// `/v1/calendar/{year}/{month}`만 답하는 대역 서버. fixture 본문으로 답합니다.
final class _CalendarServer extends Interceptor {
  /// 받은 요청 경로.
  final paths = <String>[];

  /// true면 연결 오류로 끊습니다.
  bool offline = false;

  /// 응답의 규칙 버전을 바꿉니다. null이면 fixture 값 그대로입니다.
  String? rulesetVersion;

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
    final parts = options.path.split('/');
    final month = CalendarMonth(
      int.parse(parts[parts.length - 2]),
      int.parse(parts.last),
    );
    final body = _calendarJson(month);
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

({
  CalendarRepository repository,
  CacheStore cache,
  AppDatabase database,
  _CalendarServer server,
})
_setUp() {
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(database.close);
  final cache = CacheStore(database, accountId: 'account-1');
  final server = _CalendarServer();
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..interceptors.add(server);
  return (
    repository: CalendarRepository(DefaultApi(dio), cache, FakeCrashReporter()),
    cache: cache,
    database: database,
    server: server,
  );
}

const _october = CalendarMonth(2026, 10);
const _september = CalendarMonth(2026, 9);

String _key(CalendarMonth month) => calendarKey(
  fingerprint: 'fingerprint',
  language: 'ko',
  year: month.year,
  month: month.month,
);

/// [month] 응답을 그 달 키에 직접 심습니다(규칙 버전 관찰 없이). 받은 값과 구별되게 첫 날의
/// 길흉 낱말을 바꿉니다.
Future<void> _seed(CacheStore cache, CalendarMonth month) {
  final json = _calendarJson(month);
  final days = json['days'] as List<dynamic>;
  final first = days.first as Map<String, dynamic>;
  first['level'] = {
    ...first['level'] as Map<String, dynamic>,
    'text': {
      'segments': [
        {'text': '캐시'},
      ],
    },
  };
  return cache.write(
    CacheKind.calendar,
    _key(month),
    jsonEncode(json),
    access: EvidenceAccess.locked,
    rulesetVersion: json['rulesetVersion'] as String,
  );
}

String _firstLevel(Calendar calendar) =>
    calendar.days.first.level.text.segments.single.text;

Future<int> _rowCount(AppDatabase database) async =>
    (await database.select(database.cachedResponses).get()).length;

void main() {
  group('month', () {
    test('캐시가 있으면 요청하지 않고 캐시를 돌려준다(A32)', () async {
      final s = _setUp();
      await _seed(s.cache, _october);

      final calendar = await s.repository.month(
        _october,
        cacheKey: _key(_october),
      );

      expect(s.server.paths, isEmpty);
      expect(_firstLevel(calendar), '캐시');
    });

    test('캐시가 없으면 한 번 받아 근거 열람 상태와 함께 저장한다', () async {
      final s = _setUp();

      final calendar = await s.repository.month(
        _october,
        cacheKey: _key(_october),
      );

      expect(s.server.paths, ['/v1/calendar/2026/10']);
      expect(calendar.year, 2026);
      expect(calendar.month, 10);
      expect(await s.cache.read(CacheKind.calendar, _key(_october)), isNotNull);
      expect(await s.cache.lockedKeys(CacheKind.calendar), [_key(_october)]);

      // 다음에는 저장한 캐시를 씁니다.
      await s.repository.month(_october, cacheKey: _key(_october));
      expect(s.server.paths, hasLength(1));
    });

    test('키가 없으면(사본 없음) 매번 요청하고 저장하지 않는다', () async {
      final s = _setUp();

      await s.repository.month(_october, cacheKey: null);
      await s.repository.month(_october, cacheKey: null);

      expect(s.server.paths, hasLength(2));
      expect(await _rowCount(s.database), 0);
    });

    test('깨진 캐시는 없는 것으로 보고 다시 받아 덮어쓴다', () async {
      final s = _setUp();
      await s.cache.write(
        CacheKind.calendar,
        _key(_october),
        '{"year": 2026',
        access: EvidenceAccess.locked,
      );

      final calendar = await s.repository.month(
        _october,
        cacheKey: _key(_october),
      );

      expect(s.server.paths, hasLength(1));
      expect(calendar.days, isNotEmpty);
      final stored = await s.cache.read(CacheKind.calendar, _key(_october));
      expect(jsonDecode(stored!), isA<Map<String, dynamic>>());
    });

    test('받은 rulesetVersion을 관찰해 옛 규칙의 다른 달 캐시를 버린다', () async {
      final s = _setUp();
      await s.cache.observeRulesetVersion('r0');
      await _seed(s.cache, _september);

      await s.repository.month(_october, cacheKey: _key(_october));

      expect(await s.cache.read(CacheKind.calendar, _key(_september)), isNull);
      // 방금 받은 달은 관찰 뒤에 썼으므로 남습니다.
      expect(await s.cache.read(CacheKind.calendar, _key(_october)), isNotNull);
      // 버린 달은 다음 진입에서 다시 받습니다.
      await s.repository.month(_september, cacheKey: _key(_september));
      expect(s.server.paths, ['/v1/calendar/2026/10', '/v1/calendar/2026/9']);
    });

    test('규칙 버전이 바뀌면(다른 응답이 관찰) 다음 진입에서 다시 받는다', () async {
      final s = _setUp();
      await s.repository.month(_october, cacheKey: _key(_october));
      expect(s.server.paths, hasLength(1));

      // 오늘 응답 같은 다른 응답이 새 규칙 버전을 관찰합니다.
      expect(await s.cache.observeRulesetVersion('r2'), isTrue);
      s.server.rulesetVersion = 'r2';

      await s.repository.month(_october, cacheKey: _key(_october));
      expect(s.server.paths, hasLength(2));
      await s.repository.month(_october, cacheKey: _key(_october));
      expect(s.server.paths, hasLength(2));
    });

    test('오프라인이고 캐시가 있으면 요청 없이 캐시', () async {
      final s = _setUp();
      await _seed(s.cache, _october);
      s.server.offline = true;

      final calendar = await s.repository.month(
        _october,
        cacheKey: _key(_october),
      );

      expect(_firstLevel(calendar), '캐시');
      expect(s.server.paths, isEmpty);
    });

    test('오프라인이고 캐시가 없으면 OfflineError', () async {
      final s = _setUp();
      s.server.offline = true;

      await expectLater(
        s.repository.month(_october, cacheKey: _key(_october)),
        throwsA(isA<OfflineError>()),
      );
      expect(await _rowCount(s.database), 0);
    });
  });

  test('dropLocked는 locked로 받은 달 캐시만 지운다', () async {
    final s = _setUp();
    await _seed(s.cache, _october);
    await s.cache.write(
      CacheKind.calendar,
      _key(_september),
      jsonEncode(_calendarJson(_september)),
      access: EvidenceAccess.unlocked,
    );
    await s.cache.write(
      CacheKind.chart,
      'chart-locked',
      '{}',
      access: EvidenceAccess.locked,
    );

    await s.repository.dropLocked();

    expect(await s.cache.read(CacheKind.calendar, _key(_october)), isNull);
    expect(await s.cache.read(CacheKind.calendar, _key(_september)), isNotNull);
    expect(await s.cache.lockedKeys(CacheKind.chart), ['chart-locked']);
  });
}
