import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';

/// 문자열 맵을 번들처럼 쓰는 테스트용 [AssetBundle]. 없는 키는 [FlutterError]입니다.
class _MemoryBundle extends CachingAssetBundle {
  new(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final source = files[key];
    if (source == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.sublistView(bytes);
  }
}

Scenario _scenario(String id, {List<String>? lineage, bool offline = false}) =>
    Scenario(
      id: id,
      today: DateTime(2026, 10, 13),
      timezone: 'Asia/Seoul',
      offline: offline,
      lineage: lineage,
    );

Dio _dio(Scenario scenario, AssetBundle bundle) => Dio(
  BaseOptions(baseUrl: 'http://localhost:8080'),
)..interceptors.add(FakeServerInterceptor(scenario: scenario, bundle: bundle));

DefaultApi _api(Scenario scenario, AssetBundle bundle) =>
    DefaultApi(_dio(scenario, bundle));

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
      ]);
      final newUser = scenarios.first;
      expect(newUser.today, DateTime(2026, 10, 13));
      expect(newUser.timezone, 'Asia/Seoul');
      expect(newUser.signedIn, isFalse);
      expect(scenarios.where((s) => s.signedIn), hasLength(5));
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
}
