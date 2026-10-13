import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAppCheck implements AppCheckTokenSource {
  @override
  Future<String> token() async => 'app-check-token';
}

void main() {
  late _RecordingAdapter adapter;
  late TokenStore tokens;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    tokens = TokenStore(MemorySecureStore());
    dio = buildDio(
      mode: ApiMode.http,
      baseUrl: Uri.parse('https://api.test'),
      tokens: tokens,
      appCheck: _FakeAppCheck(),
      locale: () => const Locale('ja'),
    )..httpClientAdapter = adapter;
  });

  test('X-Firebase-AppCheck는 preview와 birth-hour 요청에만 붙는다', () async {
    await dio.post<Object?>('/v1/preview');
    await dio.post<Object?>('/v1/birth-hour');
    await dio.get<Object?>('/v1/glossary');
    await dio.get<Object?>('/v1/daily/2026-10-13');

    final headers = [
      for (final r in adapter.requests) r.headers['X-Firebase-AppCheck'],
    ];
    expect(headers, ['app-check-token', 'app-check-token', null, null]);
  });

  test('Accept-Language는 access token이 없는 요청에만 붙는다', () async {
    await dio.get<Object?>('/v1/glossary');
    await tokens.save(
      TokenPair(
        accessToken: 'a',
        accessTokenExpiresAt: DateTime.utc(2026, 10, 14),
        refreshToken: 'r',
        refreshTokenExpiresAt: DateTime.utc(2026, 11),
      ),
    );
    await dio.get<Object?>('/v1/glossary');

    expect(adapter.requests[0].headers['Accept-Language'], 'ja');
    expect(adapter.requests[0].headers['Authorization'], isNull);
    expect(adapter.requests[1].headers['Accept-Language'], isNull);
    expect(adapter.requests[1].headers['Authorization'], 'Bearer a');
  });

  test('idempotent는 Idempotency-Key 헤더를 만든다', () {
    expect(idempotent('k1').headers, {'Idempotency-Key': 'k1'});
  });

  group('apiModeFromEnvironment', () {
    test('http와 debug fake는 허용한다', () {
      expect(apiModeFromEnvironment(), ApiMode.http);
      expect(apiModeFromEnvironment(value: 'fake'), ApiMode.fake);
    });

    test('release에서 fake면 StateError', () {
      expect(
        () => apiModeFromEnvironment(value: 'fake', isRelease: true),
        throwsStateError,
      );
    });

    test('알 수 없는 값이면 StateError', () {
      expect(() => apiModeFromEnvironment(value: 'x'), throwsStateError);
    });
  });

  group('baseUrlFromEnvironment', () {
    test('값이 있으면 그 값을 쓴다', () {
      expect(
        baseUrlFromEnvironment(value: 'https://api.test', isRelease: true),
        Uri.parse('https://api.test'),
      );
    });

    test('debug에서 값이 비면 localhost', () {
      expect(baseUrlFromEnvironment(), Uri.parse('http://localhost:8080'));
    });

    test('release에서 값이 비면 StateError', () {
      expect(() => baseUrlFromEnvironment(isRelease: true), throwsStateError);
    });
  });

  test('fake 모드에 fakeServer가 없으면 StateError', () {
    expect(
      () => buildDio(
        mode: ApiMode.fake,
        baseUrl: Uri.parse('https://api.test'),
        tokens: tokens,
        appCheck: _FakeAppCheck(),
        locale: () => const Locale('ko'),
      ),
      throwsStateError,
    );
  });
}
