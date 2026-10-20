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

  /// 응답의 근거 열람 상태를 바꿉니다. null이면 fixture 값(locked) 그대로입니다.
  EvidenceAccess? evidenceAccess;

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
    final access = evidenceAccess;
    if (access != null) {
      body['evidenceAccess'] = access.value;
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
  group('fetch·cached·store', () {
    test('cached는 심어 둔 캐시를 요청 없이 돌려준다', () async {
      final s = _setUp();
      await _seed(s.cache, _october);

      final calendar = await s.repository.cached(_key(_october));

      expect(s.server.paths, isEmpty);
      expect(_firstLevel(calendar!), '캐시');
    });

    test('fetch는 매번 server에 묻고, store가 근거 열람 상태와 함께 둔다', () async {
      final s = _setUp();

      final calendar = await s.repository.fetch(_october);
      await s.repository.store(_key(_october), calendar);
      await s.repository.fetch(_october);

      expect(s.server.paths, ['/v1/calendar/2026/10', '/v1/calendar/2026/10']);
      expect(calendar.year, 2026);
      expect(calendar.month, 10);
      expect(await s.repository.cached(_key(_october)), isNotNull);
      expect(await s.cache.lockedKeys(CacheKind.calendar), [_key(_october)]);
    });

    test('unlocked로 둔 달은 locked 목록에 들지 않는다', () async {
      final s = _setUp();
      s.server.evidenceAccess = EvidenceAccess.unlocked;

      await s.repository.store(
        _key(_october),
        await s.repository.fetch(_october),
      );

      expect(await s.cache.lockedKeys(CacheKind.calendar), isEmpty);
      expect(await _rowCount(s.database), 1);
    });

    test('깨진 캐시는 없는 것으로 본다', () async {
      final s = _setUp();
      await s.cache.write(
        CacheKind.calendar,
        _key(_october),
        '{"year": 2026',
        access: EvidenceAccess.locked,
      );

      expect(await s.repository.cached(_key(_october)), isNull);
    });

    test('받은 rulesetVersion을 관찰해 옛 규칙의 다른 달 캐시를 버린다', () async {
      final s = _setUp();
      await s.cache.observeRulesetVersion('r0');
      await _seed(s.cache, _september);

      final october = await s.repository.fetch(_october);
      await s.repository.store(_key(_october), october);

      expect(await s.repository.cached(_key(_september)), isNull);
      // 방금 받은 달은 관찰 뒤에 썼으므로 남습니다.
      expect(await s.repository.cached(_key(_october)), isNotNull);
    });

    test('오프라인이면 fetch는 OfflineError이고 아무것도 쓰지 않는다', () async {
      final s = _setUp();
      s.server.offline = true;

      await expectLater(
        s.repository.fetch(_october),
        throwsA(isA<OfflineError>()),
      );
      expect(await _rowCount(s.database), 0);
    });

    test(
      '달력 밖 달(1900-01)은 묻지 않고 422 date.out_of_range입니다(A44, #248)',
      () async {
        final s = _setUp();

        await expectLater(
          s.repository.fetch(const CalendarMonth(1900, 1)),
          throwsA(
            isA<ProblemError>()
                .having((e) => e.code, 'code', 'date.out_of_range')
                .having((e) => e.status, 'status', 422),
          ),
        );
        expect(s.server.paths, isEmpty);
      },
    );
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
