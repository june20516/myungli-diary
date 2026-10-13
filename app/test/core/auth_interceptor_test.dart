import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions options);

class _Adapter implements HttpClientAdapter {
  new(this.handler);

  final _Handler handler;
  final requests = <RequestOptions>[];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return Future<ResponseBody>.value(handler(options));
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAppCheck implements AppCheckTokenSource {
  @override
  Future<String> token() async => 'app-check-token';
}

ResponseBody _json(int status, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _problem(int status, String code) => ResponseBody.fromString(
  jsonEncode({
    'type': 'about:blank',
    'title': code,
    'status': status,
    'code': code,
    'traceId': 't',
  }),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/problem+json'],
  },
);

ResponseBody _tokens(String access, String refresh) => _json(200, {
  'accessToken': access,
  'accessTokenExpiresAt': '2026-10-14T00:00:00Z',
  'refreshToken': refresh,
  'refreshTokenExpiresAt': '2026-11-01T00:00:00Z',
});

DioException _connectionError(RequestOptions options) => DioException(
  requestOptions: options,
  type: DioExceptionType.connectionError,
);

void main() {
  late MemorySecureStore secure;
  late TokenStore tokens;

  setUp(() async {
    secure = MemorySecureStore();
    tokens = TokenStore(secure);
    await tokens.save(
      TokenPair(
        accessToken: 'old-access',
        accessTokenExpiresAt: DateTime.utc(2026, 10, 13),
        refreshToken: 'old-refresh',
        refreshTokenExpiresAt: DateTime.utc(2026, 11),
      ),
    );
  });

  Dio build(_Adapter adapter) => buildDio(
    mode: ApiMode.http,
    baseUrl: Uri.parse('https://api.test'),
    tokens: tokens,
    appCheck: _FakeAppCheck(),
    locale: () => const Locale('ko'),
  )..httpClientAdapter = adapter;

  /// `old-access`는 401 만료, `new-access`는 성공으로 답하는 server.
  _Adapter server({required _Handler onRefresh}) => _Adapter((options) async {
    if (options.path == '/v1/auth/refresh') {
      return await onRefresh(options);
    }
    if (options.headers['Authorization'] == 'Bearer new-access') {
      return _json(200, {'ok': true});
    }
    // 동시 요청이 모두 401을 받은 뒤 refresh가 시작되도록 한 틱 늦춥니다.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _problem(401, 'auth.token_expired');
  });

  test('동시 401 세 개에도 refresh는 한 번이고 모두 새 토큰으로 성공한다', () async {
    final adapter = server(
      onRefresh: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _tokens('new-access', 'new-refresh');
      },
    );
    final dio = build(adapter);

    final responses = await Future.wait([
      dio.get<Object?>('/v1/me'),
      dio.get<Object?>('/v1/chart'),
      dio.get<Object?>('/v1/glossary'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200, 200]);
    expect(adapter.count('/v1/auth/refresh'), 1);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer new-access');
    expect(tokens.accessToken, 'new-access');
    expect(await tokens.refreshToken(), 'new-refresh');
    // refresh 요청에는 bearer가 붙지 않습니다.
    final refresh = adapter.requests.firstWhere(
      (r) => r.path == '/v1/auth/refresh',
    );
    expect(refresh.headers['Authorization'], isNull);
  });

  test('refresh가 auth.refresh_reused 401이면 signedOut이고 토큰이 지워진다', () async {
    final adapter = server(
      onRefresh: (_) => _problem(401, 'auth.refresh_reused'),
    );
    final dio = build(adapter);
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    await expectLater(dio.get<Object?>('/v1/me'), throwsA(isA<DioException>()));
    await Future<void>.delayed(Duration.zero);

    expect(events, [AuthEvent.signedOut]);
    expect(await tokens.refreshToken(), isNull);
    expect(tokens.accessToken, isNull);
  });

  test('refresh가 다른 code의 401이어도 signedOut이다', () async {
    final adapter = server(onRefresh: (_) => _problem(401, 'auth.invalid'));
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    await expectLater(
      build(adapter).get<Object?>('/v1/me'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(events, [AuthEvent.signedOut]);
    expect(await tokens.refreshToken(), isNull);
  });

  test('refresh가 연결 오류면 로그아웃 없이 OfflineError로 끝나고 토큰이 남는다', () async {
    final adapter = server(onRefresh: (o) => throw _connectionError(o));
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    Object? caught;
    try {
      await build(adapter).get<Object?>('/v1/me');
    } on DioException catch (e) {
      caught = appErrorFrom(e);
    }
    await Future<void>.delayed(Duration.zero);

    expect(caught, isA<OfflineError>());
    expect(events, isEmpty);
    expect(await tokens.refreshToken(), 'old-refresh');
    expect(tokens.accessToken, 'old-access');
  });

  test('refresh가 시간 초과면 TimeoutError로 끝나고 토큰이 남는다', () async {
    final adapter = server(
      onRefresh: (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    Object? caught;
    try {
      await build(adapter).get<Object?>('/v1/me');
    } on DioException catch (e) {
      caught = appErrorFrom(e);
    }

    expect(caught, isA<TimeoutError>());
    expect(await tokens.refreshToken(), 'old-refresh');
  });

  test('refresh가 5xx면 로그아웃 없이 그 오류로 끝난다', () async {
    final adapter = server(
      onRefresh: (_) => _problem(503, 'server.unavailable'),
    );
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    Object? caught;
    try {
      await build(adapter).get<Object?>('/v1/me');
    } on DioException catch (e) {
      caught = appErrorFrom(e);
    }
    await Future<void>.delayed(Duration.zero);

    expect(caught, isA<ProblemError>().having((e) => e.status, 'status', 503));
    expect(events, isEmpty);
    expect(await tokens.refreshToken(), 'old-refresh');
  });

  test('refresh가 503 auth.provider_unavailable이어도 로그아웃하지 않는다', () async {
    final adapter = server(
      onRefresh: (_) => _problem(503, 'auth.provider_unavailable'),
    );
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    Object? caught;
    try {
      await build(adapter).get<Object?>('/v1/me');
    } on DioException catch (e) {
      caught = appErrorFrom(e);
    }
    await Future<void>.delayed(Duration.zero);

    expect(
      caught,
      isA<ProblemError>().having(
        (e) => e.code,
        'code',
        'auth.provider_unavailable',
      ),
    );
    expect(events, isEmpty);
    expect(await tokens.refreshToken(), 'old-refresh');
  });

  test('요청이 503 auth.provider_unavailable이면 refresh·로그아웃 없이 실패한다', () async {
    final adapter = _Adapter((_) => _problem(503, 'auth.provider_unavailable'));
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    await expectLater(
      build(adapter).get<Object?>('/v1/me'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(adapter.count('/v1/auth/refresh'), 0);
    expect(events, isEmpty);
    expect(tokens.accessToken, 'old-access');
  });

  test('403 consent.required면 consentRequired를 알리고 그 오류로 끝난다', () async {
    final adapter = _Adapter((_) => _problem(403, 'consent.required'));
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    Object? caught;
    try {
      await build(adapter).get<Object?>('/v1/chart');
    } on DioException catch (e) {
      caught = appErrorFrom(e);
    }
    await Future<void>.delayed(Duration.zero);

    expect(
      caught,
      isA<ProblemError>()
          .having((e) => e.status, 'status', 403)
          .having((e) => e.code, 'code', 'consent.required'),
    );
    expect(events, [AuthEvent.consentRequired]);
    expect(adapter.requests, hasLength(1));
    expect(tokens.accessToken, 'old-access');
  });

  test('consent.required가 아닌 403은 알리지 않는다', () async {
    final adapter = _Adapter((_) => _problem(403, 'preview.used'));
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);

    await expectLater(
      build(adapter).get<Object?>('/v1/chart'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(events, isEmpty);
  });

  test('재시도도 401이면 refresh를 되풀이하지 않고 그대로 실패한다', () async {
    final adapter = _Adapter((options) {
      if (options.path == '/v1/auth/refresh') {
        return _tokens('new-access', 'new-refresh');
      }
      return _problem(401, 'auth.token_expired');
    });

    await expectLater(
      build(adapter).get<Object?>('/v1/me'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.count('/v1/auth/refresh'), 1);
    expect(adapter.count('/v1/me'), 2);
  });

  test('token_expired가 아닌 401은 refresh하지 않는다', () async {
    final adapter = _Adapter((_) => _problem(401, 'auth.invalid'));

    await expectLater(
      build(adapter).get<Object?>('/v1/me'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.count('/v1/auth/refresh'), 0);
  });

  group('세션 복원(재실행 직후: refresh token만 있음)', () {
    setUp(() {
      tokens = TokenStore(secure);
    });

    test('인증이 필요한 요청은 refresh 한 번 뒤 bearer를 붙여 성공한다', () async {
      final adapter = server(
        onRefresh: (_) => _tokens('new-access', 'new-refresh'),
      );

      final response = await build(adapter).get<Object?>('/v1/me');

      expect(response.statusCode, 200);
      expect(adapter.count('/v1/auth/refresh'), 1);
      expect(adapter.count('/v1/me'), 1);
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer new-access',
      );
    });

    test('동시 3건도 refresh는 한 번이다', () async {
      final adapter = server(
        onRefresh: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _tokens('new-access', 'new-refresh');
        },
      );
      final dio = build(adapter);

      final responses = await Future.wait([
        dio.get<Object?>('/v1/me'),
        dio.get<Object?>('/v1/chart'),
        dio.get<Object?>('/v1/glossary'),
      ]);

      expect(responses.map((r) => r.statusCode), [200, 200, 200]);
      expect(adapter.count('/v1/auth/refresh'), 1);
    });

    test('bearer가 필요 없는 요청은 refresh하지 않는다', () async {
      final adapter = _Adapter((_) => _json(200, {}));
      final dio = build(adapter);

      await dio.get<Object?>('/v1/app-config');
      await dio.post<Object?>('/v1/preview');

      expect(adapter.count('/v1/auth/refresh'), 0);
    });

    test('refresh가 연결 오류면 OfflineError이고 로그아웃·토큰 삭제가 없다', () async {
      final adapter = server(onRefresh: (o) => throw _connectionError(o));
      final events = <AuthEvent>[];
      tokens.events.listen(events.add);

      Object? caught;
      try {
        await build(adapter).get<Object?>('/v1/me');
      } on DioException catch (e) {
        caught = appErrorFrom(e);
      }
      await Future<void>.delayed(Duration.zero);

      expect(caught, isA<OfflineError>());
      expect(events, isEmpty);
      expect(await tokens.refreshToken(), 'old-refresh');
      expect(adapter.count('/v1/me'), 0);
    });

    test('refresh가 401(refresh_reused)이면 signOut하고 요청은 실패한다', () async {
      final adapter = server(
        onRefresh: (_) => _problem(401, 'auth.refresh_reused'),
      );
      final events = <AuthEvent>[];
      tokens.events.listen(events.add);

      Object? caught;
      try {
        await build(adapter).get<Object?>('/v1/me');
      } on DioException catch (e) {
        caught = appErrorFrom(e);
      }
      await Future<void>.delayed(Duration.zero);

      expect(caught, isA<ProblemError>());
      expect(events, [AuthEvent.signedOut]);
      expect(await tokens.refreshToken(), isNull);
      expect(adapter.count('/v1/me'), 0);
    });

    test('두 토큰이 모두 없으면 그대로 보낸다', () async {
      await secure.delete('auth.refresh');
      final adapter = _Adapter((_) => _problem(401, 'auth.unauthenticated'));

      await expectLater(
        build(adapter).get<Object?>('/v1/me'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.count('/v1/auth/refresh'), 0);
      expect(adapter.requests.single.headers['Authorization'], isNull);
    });
  });

  group('동시성 분기', () {
    test('refresh 완료 뒤 늦게 온 401은 refresh 없이 새 토큰으로 재시도한다', () async {
      final adapter = _Adapter((options) async {
        if (options.path == '/v1/auth/refresh') {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return _tokens('new-access', 'new-refresh');
        }
        if (options.headers['Authorization'] == 'Bearer new-access') {
          return _json(200, {'ok': true});
        }
        // /v1/chart의 401은 refresh가 끝난 뒤에 도착합니다.
        final delay = options.path == '/v1/chart' ? 120 : 5;
        await Future<void>.delayed(Duration(milliseconds: delay));
        return _problem(401, 'auth.token_expired');
      });
      final dio = build(adapter);

      final responses = await Future.wait([
        dio.get<Object?>('/v1/me'),
        dio.get<Object?>('/v1/chart'),
      ]);

      expect(responses.map((r) => r.statusCode), [200, 200]);
      expect(adapter.count('/v1/auth/refresh'), 1);
    });

    test('refresh가 연결 오류로 실패한 뒤 다음 401은 refresh를 다시 시도한다', () async {
      var refreshCalls = 0;
      final adapter = server(
        onRefresh: (options) {
          refreshCalls++;
          if (refreshCalls == 1) {
            throw _connectionError(options);
          }
          return _tokens('new-access', 'new-refresh');
        },
      );
      final dio = build(adapter);

      await expectLater(
        dio.get<Object?>('/v1/me'),
        throwsA(isA<DioException>()),
      );
      final response = await dio.get<Object?>('/v1/me');

      expect(response.statusCode, 200);
      expect(adapter.count('/v1/auth/refresh'), 2);
    });

    test('동시 3건에서 refresh가 401로 거부되면 모두 실패하고 signedOut은 한 번이다', () async {
      final adapter = server(
        onRefresh: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _problem(401, 'auth.refresh_reused');
        },
      );
      final dio = build(adapter);
      final events = <AuthEvent>[];
      tokens.events.listen(events.add);

      final results = await Future.wait([
        for (final path in ['/v1/me', '/v1/chart', '/v1/glossary'])
          dio
              .get<Object?>(path)
              .then<Object?>((_) => null)
              .catchError((Object e) => e),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(results, everyElement(isA<DioException>()));
      expect(adapter.count('/v1/auth/refresh'), 1);
      expect(events, [AuthEvent.signedOut]);
    });

    test('refresh token이 없으면 signOut하고 401 ProblemError로 끝난다', () async {
      await secure.delete('auth.refresh');
      final adapter = server(onRefresh: (_) => _tokens('a', 'r'));
      final events = <AuthEvent>[];
      tokens.events.listen(events.add);

      Object? caught;
      try {
        await build(adapter).get<Object?>('/v1/me');
      } on DioException catch (e) {
        caught = appErrorFrom(e);
      }
      await Future<void>.delayed(Duration.zero);

      expect(
        caught,
        isA<ProblemError>().having((e) => e.status, 'status', 401),
      );
      expect(events, [AuthEvent.signedOut]);
      expect(adapter.count('/v1/auth/refresh'), 0);
    });

    test('signOut 뒤 늦게 온 401은 재시도 없이 실패한다', () async {
      final adapter = _Adapter((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _problem(401, 'auth.token_expired');
      });
      final dio = build(adapter);

      final pending = dio.get<Object?>('/v1/me');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await tokens.clear();

      await expectLater(pending, throwsA(isA<DioException>()));
      expect(adapter.count('/v1/me'), 1);
      expect(adapter.count('/v1/auth/refresh'), 0);
    });

    test('토큰이 없으면 남아 있던 Authorization 헤더를 지운다', () async {
      await tokens.clear();
      final adapter = _Adapter((_) => _json(200, {}));

      await build(adapter).get<Object?>(
        '/v1/app-config',
        options: Options(headers: {'Authorization': 'Bearer stale'}),
      );

      expect(adapter.requests.single.headers['Authorization'], isNull);
    });
  });
}
