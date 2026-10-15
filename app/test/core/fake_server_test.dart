import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_route.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:yaml/yaml.dart';

/// 문자열 맵을 번들처럼 쓰는 테스트용 [AssetBundle]. 없는 키는 [FlutterError]입니다.
class _MemoryBundle extends CachingAssetBundle {
  new(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return _manifestOf(files.keys);
    }
    final source = files[key];
    if (source == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.sublistView(bytes);
  }
}

/// `AssetManifest.bin` 내용: key마다 변형 하나.
ByteData _manifestOf(Iterable<String> keys) =>
    const StandardMessageCodec().encodeMessage({
      for (final key in keys)
        key: [
          {'asset': key},
        ],
    })!;

Scenario _scenario(String id, {List<String>? lineage, bool offline = false}) =>
    Scenario(
      id: id,
      today: CalendarDate(2026, 10, 13),
      timezone: 'Asia/Seoul',
      offline: offline,
      lineage: lineage,
    );

Dio _dio(Scenario scenario, AssetBundle bundle) => Dio(
  BaseOptions(baseUrl: 'http://localhost:8080'),
)..interceptors.add(FakeServerInterceptor(scenario: scenario, bundle: bundle));

DefaultApi _api(Scenario scenario, AssetBundle bundle) =>
    DefaultApi(_dio(scenario, bundle));

class _FakeAppCheck implements AppCheckTokenSource {
  @override
  Future<String> token() async => 'app-check';
}

const Map<String, Object?> _expiredProblem = {
  'status': 401,
  'body': {
    'type': 'https://api.myungli.app/problems/auth.token_expired',
    'title': 'Token expired',
    'status': 401,
    'code': 'auth.token_expired',
    'traceId': 't',
  },
};

final Map<String, Object?> _meResponse = {
  'status': 200,
  'body': {
    'accountId': '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10',
    'status': 'active',
    'consentRequired': false,
    'requiredConsents': <Object?>[],
    'hasProfile': true,
    'adFree': {'active': false},
    'insight': {'active': false},
  },
};

const Map<String, Object?> _tokenResponse = {
  'status': 200,
  'body': {
    'accessToken': 'fake-new-access',
    'accessTokenExpiresAt': '2026-10-13T01:00:00Z',
    'refreshToken': 'fake-new-refresh',
    'refreshTokenExpiresAt': '2026-11-12T00:00:00Z',
  },
};

String _calendar(int status, [String marker = 'x']) => jsonEncode({
  'status': status,
  'body': {'marker': marker},
});

Future<AppError> _errorOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    return appErrorFrom(e);
  }
  throw StateError('오류가 나야 합니다.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('member 시나리오에서 GET /v1/me는 200이고 Me로 읽힌다', () async {
    final scenarios = await loadScenarios(rootBundle);
    final member = scenarios.firstWhere((s) => s.id == 'member');
    final response = await _api(member, rootBundle).getMe();
    expect(response.statusCode, 200);
    expect(response.data!.hasProfile, isTrue);
    expect(response.data!.consentRequired, isFalse);
  });

  test('extends 부모의 fixture를 쓰고 자식 fixture가 우선한다', () async {
    final scenarios = {
      for (final s in await loadScenarios(rootBundle)) s.id: s,
    };
    expect(scenarios['member']!.lineage, ['member', 'new-user']);
    final inherited = await _api(
      scenarios['member']!,
      rootBundle,
    ).getAppConfig();
    expect(inherited.data!.minimumVersion.ios, '1.0.0');
    final overridden = await _api(
      scenarios['force-update']!,
      rootBundle,
    ).getAppConfig();
    expect(overridden.data!.minimumVersion.ios, '99.0.0');
  });

  test('매개변수 파일이 기본 파일보다 우선한다', () async {
    final bundle = _MemoryBundle({
      'fixtures/s/getCalendar.json': _calendar(200, 'default'),
      'fixtures/s/getCalendar__2026-10.json': _calendar(200, 'param'),
    });
    final dio = _dio(_scenario('s'), bundle);
    final preferred = await dio.get<Map<String, Object?>>(
      '/v1/calendar/2026/10',
    );
    expect(preferred.data!['marker'], 'param');
    final fallback = await dio.get<Map<String, Object?>>(
      '/v1/calendar/2026/11',
    );
    expect(fallback.data!['marker'], 'default');
  });

  test('fixture가 없는 operation은 501 not_implemented', () async {
    final error = await _errorOf(
      () => _api(_scenario('s'), _MemoryBundle({})).getMe(),
    );
    expect(error, isA<ProblemError>());
    final problem = error as ProblemError;
    expect(problem.code, 'not_implemented');
    expect(problem.status, 501);
    expect(problem.traceId, isNotEmpty);
  });

  test('route 표에 없는 경로는 404 route.not_found', () async {
    final dio = _dio(_scenario('s'), _MemoryBundle({}));
    final error = await _errorOf(() => dio.get<Object?>('/v1/nowhere'));
    expect(error, isA<ProblemError>());
    final problem = error as ProblemError;
    expect(problem.code, 'route.not_found');
    expect(problem.status, 404);
  });

  test('fixture의 4xx는 problem+json으로 답한다', () async {
    final bundle = _MemoryBundle({
      'fixtures/s/getMe.json': jsonEncode({
        'status': 401,
        'body': {
          'type': 'https://api.myungli.app/problems/auth.token_invalid',
          'title': 'Invalid token',
          'status': 401,
          'code': 'auth.token_invalid',
          'traceId': 't',
        },
      }),
    });
    final error = await _errorOf(() => _api(_scenario('s'), bundle).getMe());
    expect((error as ProblemError).code, 'auth.token_invalid');
  });

  test('offline 시나리오는 OfflineError', () async {
    final scenarios = await loadScenarios(rootBundle);
    final offline = scenarios.firstWhere((s) => s.id == 'offline');
    expect(offline.offline, isTrue);
    final error = await _errorOf(() => _api(offline, rootBundle).getMe());
    expect(error, isA<OfflineError>());
  });

  group('scenarios.json', () {
    test('기반 시나리오를 읽는다', () async {
      final scenarios = await loadScenarios(rootBundle);
      expect(scenarios.map((s) => s.id), [
        'new-user',
        'member',
        'consent-required',
        'profile-required',
        'force-update',
        'offline',
        'member-overseas',
        'birth-hour-unavailable',
        'overseas',
        'birth-hour-rate-limited',
        'cities-error',
        'cities-slow',
        'time-unknown',
        'preview-used',
        'preview-invalid',
        'returning-user',
        'login-provider-down',
        'login-exchange-invalid',
        'new-user-signin',
        'consent-mismatch',
        'profile-invalid',
        'profile-save-unavailable',
        'notify-register-unavailable',
        'consent-renewal',
        'notify-profile-save-unavailable',
        'profile-name-invalid',
        'login-entry-unavailable',
        'member-time-unknown',
        'daily-error',
        'diary-written',
        'reaction-failed',
        'reaction-delete-failed',
      ]);
      final newUser = scenarios.first;
      expect(newUser.today, CalendarDate(2026, 10, 13));
      expect(newUser.timezone, 'Asia/Seoul');
      expect(newUser.signedIn, isFalse);
      expect(scenarios.where((s) => s.signedIn), hasLength(15));
      expect(
        scenarios.singleWhere((s) => s.id == 'overseas').locale,
        const Locale('en', 'US'),
      );
    });

    test('extends 순환은 오류다', () {
      const source = '''
[
  {"id": "a", "extends": "b", "today": "2026-10-13", "timezone": "Asia/Seoul"},
  {"id": "b", "extends": "a", "today": "2026-10-13", "timezone": "Asia/Seoul"}
]''';
      expect(
        () => parseScenarios(source),
        throwsA(
          isA<ScenarioFormatException>().having(
            (e) => e.message,
            'message',
            contains('순환'),
          ),
        ),
      );
    });

    test('자기 자신을 extends해도 오류다', () {
      const source =
          '[{"id": "a", "extends": "a", "today": "2026-10-13", "timezone": "Asia/Seoul"}]';
      expect(
        () => parseScenarios(source),
        throwsA(isA<ScenarioFormatException>()),
      );
    });

    test('없는 부모와 id 중복은 오류다', () {
      const missing =
          '[{"id": "a", "extends": "zzz", "today": "2026-10-13", "timezone": "Asia/Seoul"}]';
      expect(
        () => parseScenarios(missing),
        throwsA(isA<ScenarioFormatException>()),
      );
      const duplicated = '''
[
  {"id": "a", "today": "2026-10-13", "timezone": "Asia/Seoul"},
  {"id": "a", "today": "2026-10-13", "timezone": "Asia/Seoul"}
]''';
      expect(
        () => parseScenarios(duplicated),
        throwsA(isA<ScenarioFormatException>()),
      );
    });
  });

  group('sequence', () {
    test('n번째 호출은 n번째 응답이고 넘으면 마지막을 되풀이한다', () async {
      final bundle = _MemoryBundle({
        'fixtures/s/getCalendar.json': jsonEncode({
          'sequence': [
            {
              'status': 200,
              'body': {'marker': 'first'},
            },
            {
              'status': 200,
              'body': {'marker': 'second'},
            },
          ],
        }),
      });
      final dio = _dio(_scenario('s'), bundle);
      Future<Object?> marker() async =>
          (await dio.get<Map<String, Object?>>('/v1/calendar/2026/10'))
              .data!['marker'];
      expect(await marker(), 'first');
      expect(await marker(), 'second');
      expect(await marker(), 'second');
    });

    test('호출 수는 인스턴스마다 새로 센다', () async {
      final bundle = _MemoryBundle({
        'fixtures/s/getCalendar.json': jsonEncode({
          'sequence': [
            {
              'status': 200,
              'body': {'marker': 'first'},
            },
            {
              'status': 200,
              'body': {'marker': 'second'},
            },
          ],
        }),
      });
      for (var i = 0; i < 2; i++) {
        final dio = _dio(_scenario('s'), bundle);
        final response = await dio.get<Map<String, Object?>>(
          '/v1/calendar/2026/10',
        );
        expect(response.data!['marker'], 'first');
      }
    });
  });

  group('fake 모드 인증 흐름', () {
    late TokenStore tokens;

    setUp(() async {
      tokens = TokenStore(MemorySecureStore());
      await tokens.save(
        TokenPair(
          accessToken: 'old-access',
          accessTokenExpiresAt: DateTime.utc(2026, 10, 13),
          refreshToken: 'old-refresh',
          refreshTokenExpiresAt: DateTime.utc(2026, 11),
        ),
      );
    });

    tearDown(() => tokens.dispose());

    late FakeServerInterceptor fake;

    DefaultApi api(_MemoryBundle bundle) {
      fake = FakeServerInterceptor(scenario: _scenario('s'), bundle: bundle);
      return DefaultApi(
        buildDio(
          mode: ApiMode.fake,
          baseUrl: Uri.parse('http://localhost:8080'),
          tokens: tokens,
          appCheck: _FakeAppCheck(),
          locale: () => const Locale('ko'),
          fakeServer: fake,
        ),
      );
    }

    test('401 만료 -> refresh 1회 -> 토큰 저장 -> 재시도 성공', () async {
      final bundle = _MemoryBundle({
        'fixtures/s/getMe.json': jsonEncode({
          'sequence': [_expiredProblem, _meResponse],
        }),
        'fixtures/s/refreshToken.json': jsonEncode(_tokenResponse),
      });
      final response = await api(bundle).getMe();
      expect(response.statusCode, 200);
      expect(response.data!.hasProfile, isTrue);
      expect(fake.callCountOf('refreshToken'), 1);
      expect(fake.callCountOf('getMe'), 2);
      expect(tokens.accessToken, 'fake-new-access');
      expect(await tokens.refreshToken(), 'fake-new-refresh');
    });

    test('항상 401이면 refresh 1회 뒤 재시도도 401로 ProblemError', () async {
      // 세 번째 호출은 200입니다. 재시도 가드가 빠지면 세 번째까지 가서 성공하므로
      // 시간 초과가 아니라 단언으로 실패합니다.
      final bundle = _MemoryBundle({
        'fixtures/s/getMe.json': jsonEncode({
          'sequence': [_expiredProblem, _expiredProblem, _meResponse],
        }),
        'fixtures/s/refreshToken.json': jsonEncode(_tokenResponse),
      });
      final error = await _errorOf(() => api(bundle).getMe());
      expect(error, isA<ProblemError>());
      expect((error as ProblemError).code, 'auth.token_expired');
      expect(error.status, 401);
      expect(fake.callCountOf('refreshToken'), 1);
      expect(fake.callCountOf('getMe'), 2);
    });
  });

  test('sequence가 다른 키와 섞이거나 비면 형식 오류', () async {
    for (final source in [
      '{"sequence": [], "status": 200}',
      '{"sequence": []}',
      '{"sequence": [{"status": 200}], "body": 1}',
    ]) {
      final bundle = _MemoryBundle({'fixtures/s/getMe.json': source});
      try {
        await _api(_scenario('s'), bundle).getMe();
        fail('오류가 나야 합니다: $source');
      } on DioException catch (e) {
        expect(e.error, isA<FormatException>(), reason: source);
      }
    }
  });

  group('asset 읽기', () {
    test('manifest 읽기가 한 번 실패해도 다음 요청은 다시 읽는다', () async {
      final bundle = _FlakyManifestBundle({
        'fixtures/s/getMe.json': jsonEncode(_meResponse),
      });
      final dioApi = _api(_scenario('s'), bundle);
      try {
        await dioApi.getMe();
        fail('첫 요청은 manifest 오류여야 합니다.');
      } on DioException catch (e) {
        expect(e.error, isA<FlutterError>());
      }
      final response = await dioApi.getMe();
      expect(response.statusCode, 200);
      expect(bundle.manifestLoads, 2);
    });

    test('번들에 없음이 아닌 읽기 오류는 501로 삼키지 않고 드러낸다', () async {
      final bundle = _BrokenBundle();
      try {
        await _api(_scenario('s'), bundle).getMe();
        fail('오류가 나야 합니다.');
      } on DioException catch (e) {
        expect(e.error, isA<FlutterError>());
        expect(e.response, isNull);
      }
    });
  });

  group('delay', () {
    test('delayMs만큼 기다린 뒤 답한다', () async {
      final scenario = Scenario(
        id: 's',
        today: CalendarDate(2026, 10, 13),
        timezone: 'Asia/Seoul',
        delay: const Duration(milliseconds: 80),
      );
      final bundle = _MemoryBundle({
        'fixtures/s/getMe.json': jsonEncode(_meResponse),
      });
      final stopwatch = Stopwatch()..start();
      await _api(scenario, bundle).getMe();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(80));
    });
  });

  group('scenarios.json 값 검사', () {
    String one(String extra) =>
        '[{"id": "a", "today": "2026-10-13", "timezone": "Asia/Seoul"$extra}]';

    test('delayMs가 정수가 아니거나 음수면 오류다', () {
      for (final bad in ['"100"', '1.5', '-1', 'true']) {
        expect(
          () => parseScenarios(one(', "delayMs": $bad')),
          throwsA(isA<ScenarioFormatException>()),
          reason: bad,
        );
      }
      expect(
        parseScenarios(one(', "delayMs": 25')).single.delay,
        const Duration(milliseconds: 25),
      );
    });

    test('locale은 언어-국가 형식으로 읽고, 없으면 null이며, 틀리면 오류다', () {
      expect(parseScenarios(one('')).single.locale, isNull);
      expect(
        parseScenarios(one(', "locale": "en-US"')).single.locale,
        const Locale('en', 'US'),
      );
      expect(
        parseScenarios(one(', "locale": "ko"')).single.locale,
        const Locale('ko'),
      );
      for (final bad in ['""', '"en_US"', '"e-US"', '1', '"en-USA"']) {
        expect(
          () => parseScenarios(one(', "locale": $bad')),
          throwsA(isA<ScenarioFormatException>()),
          reason: bad,
        );
      }
    });

    test('network가 online·offline이 아니면 오류다', () {
      expect(
        () => parseScenarios(one(', "network": "flaky"')),
        throwsA(isA<ScenarioFormatException>()),
      );
      expect(
        parseScenarios(one(', "network": "offline"')).single.offline,
        isTrue,
      );
    });
  });

  group('fixtures 폴더 가드', () {
    final folders = Directory('fixtures')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final assets = ((pubspec['flutter'] as YamlMap)['assets'] as YamlList)
        .cast<String>()
        .toSet();
    final scenarios = parseScenarios(
      File('fixtures/scenarios.json').readAsStringSync(),
    );

    test('모든 fixtures 하위 폴더와 fixtures/ 자체가 pubspec assets에 있다', () {
      expect(assets, contains('fixtures/'));
      for (final folder in folders) {
        expect(assets, contains('fixtures/$folder/'), reason: folder);
      }
    });

    test('pubspec의 fixtures asset은 실제 폴더를 가리킨다', () {
      for (final asset in assets.where(
        (a) => a.startsWith('fixtures/') && a != 'fixtures/',
      )) {
        expect(Directory(asset).existsSync(), isTrue, reason: asset);
      }
    });

    test('폴더 이름은 모두 시나리오 id이고, 폴더 없는 시나리오는 extends가 있다', () {
      final ids = scenarios.map((s) => s.id).toSet();
      expect(
        ids.containsAll(folders),
        isTrue,
        reason: '시나리오 없는 폴더: ${folders.difference(ids)}',
      );
      for (final scenario in scenarios.where((s) => !folders.contains(s.id))) {
        expect(
          scenario.lineage.length,
          greaterThan(1),
          reason: '${scenario.id}: fixture 폴더도 extends도 없습니다',
        );
      }
    });
  });

  test('routePathOf는 base URL의 path 접두어를 뗀다', () {
    String pathOf(String base, String path) =>
        routePathOf(RequestOptions(baseUrl: base, path: path));
    expect(pathOf('http://h:8080', '/v1/me'), '/v1/me');
    expect(pathOf('https://h/api/', '/v1/me'), '/v1/me');
    expect(pathOf('https://h/api', '/v1/me'), '/v1/me');
    expect(matchRoute('GET', pathOf('https://h/api', '/v1/me')), isNotNull);
  });
}

/// manifest에는 있지만 읽으면 실패하는 번들.
class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return _manifestOf(['fixtures/s/getMe.json']);
    }
    throw FlutterError('디스크 오류');
  }
}

/// 첫 manifest 읽기만 실패하는 번들.
class _FlakyManifestBundle extends _MemoryBundle {
  new(super.files);

  int manifestLoads = 0;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      manifestLoads++;
      if (manifestLoads == 1) {
        throw FlutterError('manifest 디스크 오류');
      }
    }
    return await super.load(key);
  }
}
