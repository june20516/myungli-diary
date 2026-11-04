import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../tool/e2e_staging/relay_core.dart';

/// staging E2E relay(#781)가 staging 경로를 계약대로 부르고, 비밀과 토큰을 로그에 남기지 않는지
/// 확인합니다. staging server는 [MockClient]로 대신합니다.
void main() {
  const secret = 'S';
  final apiBase = Uri.parse('https://staging.example');

  /// label마다 다른 accessToken을 주는 테스트 로그인 응답입니다.
  String loginBody(String label, {bool consentRequired = true}) => jsonEncode({
    'tokens': {
      'accessToken': 'access-$label',
      'accessTokenExpiresAt': '2026-11-04T10:00:00Z',
      'refreshToken': 'refresh-$label',
      'refreshTokenExpiresAt': '2026-12-04T10:00:00Z',
    },
    'isNewAccount': true,
    'consentRequired': consentRequired,
  });

  const meBody =
      '{"accountId":"7b0c7d1e-0000-4000-8000-000000000001",'
      '"consentRequired":true,'
      '"requiredConsents":[{"document":"terms","version":"2026-10-01"},'
      '{"document":"privacy","version":"2026-10-02"}],'
      '"hasProfile":false,'
      '"adFree":{"active":false},"insight":{"active":false}}';

  /// 받은 요청을 [requests]에 쌓고 정상 응답을 주는 staging 대역입니다.
  /// [override]가 응답을 주면 그 응답을 씁니다.
  MockClient stagingServer(
    List<http.Request> requests, {
    http.Response? Function(http.Request request)? override,
  }) => MockClient((request) async {
    requests.add(request);
    final custom = override?.call(request);
    if (custom != null) return custom;
    final route = '${request.method} ${request.url.path}';
    switch (route) {
      case 'POST /test/v1/auth/login':
        final label = (jsonDecode(request.body) as Map)['label'] as String;
        return http.Response(loginBody(label), 200);
      case 'GET /v1/me':
        return http.Response(meBody, 200);
      case 'POST /v1/me/consents':
      case 'DELETE /v1/me':
        return http.Response('', 204);
      case 'PUT /v1/me/profile':
        return http.Response('{"warnings":[]}', 200);
      case 'POST /test/v1/billing/ad-free':
        return http.Response('{"adFree":{"active":true}}', 200);
    }
    return http.Response('{"code":"route.not_found"}', 404);
  });

  test('login은 비밀 헤더를 붙여 테스트 로그인으로 보내고 label을 기억합니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(requests),
    );

    final response = await relay.handle('POST', '/login', {'label': 'e2eAbc'});

    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.url, apiBase.resolve('/test/v1/auth/login'));
    expect(request.headers['X-Test-Login-Secret'], secret);
    expect(jsonDecode(request.body), {'label': 'e2eAbc'});
    expect(response.status, 200);
    expect(response.body, loginBody('e2eAbc'));
    expect(relay.labels, {'e2eAbc'});
  });

  test('label 형식이 틀리면 staging을 부르지 않고 400입니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(requests),
    );

    for (final label in ['bad-label', 'e2e${'a' * 30}', 'abc', '', 42]) {
      final login = await relay.handle('POST', '/login', {'label': label});
      final session = await relay.handle('POST', '/session', {'label': label});
      expect(login.status, 400, reason: '$label');
      expect(session.status, 400, reason: '$label');
    }
    expect(requests, isEmpty);
    expect(relay.labels, isEmpty);
    expect(isRelayLabel('e2e1762230000000Ab12'), isTrue);
    expect(isRelayLabel('e2e${'a' * 29}'), isTrue);
    expect(isRelayLabel('e2e${'a' * 30}'), isFalse);
  });

  test('session은 동의, 프로필, 광고 제거 기간을 차례로 부르고 refreshToken만 돌려줍니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(requests),
    );

    final response = await relay.handle('POST', '/session', {
      'label': 'e2eSes',
      'profile': true,
      'adFreeDays': 30,
    });

    expect(response.status, 200);
    expect(jsonDecode(response.body), {'refreshToken': 'refresh-e2eSes'});
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /test/v1/auth/login',
      'GET /v1/me',
      'POST /v1/me/consents',
      'PUT /v1/me/profile',
      'POST /test/v1/billing/ad-free',
    ]);
    for (final request in requests.sublist(1, 4)) {
      expect(request.headers['Authorization'], 'Bearer access-e2eSes');
      expect(request.headers.containsKey('X-Test-Login-Secret'), isFalse);
    }
    expect(jsonDecode(requests[2].body), {
      'documents': [
        {'document': 'terms', 'version': '2026-10-01'},
        {'document': 'privacy', 'version': '2026-10-02'},
      ],
    });
    expect(jsonDecode(requests[3].body), {
      'honorific': '별님',
      'language': 'ko',
      'currentTimezone': 'Asia/Seoul',
      'birth': {
        'calendar': 'solar',
        'date': {'year': 1990, 'month': 5, 'day': 15},
        'isLeapMonth': false,
        'time': {'status': 'known', 'value': '10:30'},
        'gender': 'female',
        'timezone': 'Asia/Seoul',
        'place': {'status': 'not_asked'},
      },
      'notification': {'status': 'not_asked'},
    });
    final grant = requests[4];
    expect(grant.headers['X-Test-Login-Secret'], secret);
    expect(jsonDecode(grant.body), {
      'accountId': '7b0c7d1e-0000-4000-8000-000000000001',
      'days': 30,
    });
    expect(relay.labels, {'e2eSes'});
  });

  test('session은 동의가 필요 없고 프로필, 광고 제거를 원하지 않으면 로그인만 합니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(
        requests,
        override: (request) => request.url.path == '/test/v1/auth/login'
            ? http.Response(loginBody('e2eMin', consentRequired: false), 200)
            : null,
      ),
    );

    final response = await relay.handle('POST', '/session', {
      'label': 'e2eMin',
    });

    expect(response.status, 200);
    expect(jsonDecode(response.body), {'refreshToken': 'refresh-e2eMin'});
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /test/v1/auth/login',
    ]);
  });

  test('session의 profile, adFreeDays 타입이 틀리면 staging을 부르지 않고 400입니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(requests),
    );

    for (final body in [
      {'label': 'e2eBad', 'profile': 'yes'},
      {'label': 'e2eBad', 'adFreeDays': -1},
      {'label': 'e2eBad', 'adFreeDays': 1.5},
      'not a map',
    ]) {
      final response = await relay.handle('POST', '/session', body);
      expect(response.status, 400, reason: '$body');
    }
    expect(requests, isEmpty);
  });

  test(
    'cleanup은 기억한 label마다 로그인 후 DELETE /v1/me를 부르고 실패한 label을 알립니다',
    () async {
      final requests = <http.Request>[];
      final relay = StagingRelay(
        apiBase: apiBase,
        secret: secret,
        client: stagingServer(
          requests,
          override: (request) =>
              request.method == 'DELETE' &&
                  request.headers['Authorization'] == 'Bearer access-e2eFail'
              ? http.Response('{"code":"internal"}', 500)
              : null,
        ),
      );
      await relay.handle('POST', '/login', {'label': 'e2eOne'});
      await relay.handle('POST', '/login', {'label': 'e2eFail'});
      requests.clear();

      final response = await relay.handle('POST', '/cleanup', null);

      expect(response.status, 200);
      expect(jsonDecode(response.body), {
        'deleted': 1,
        'failed': ['e2eFail'],
      });
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /test/v1/auth/login',
        'DELETE /v1/me',
        'POST /test/v1/auth/login',
        'DELETE /v1/me',
      ]);
      expect(requests[1].headers['Authorization'], 'Bearer access-e2eOne');
      // 지운 label은 잊어, 다시 정리해도 지운 계정을 새로 만들지 않습니다.
      expect(relay.labels, {'e2eFail'});
    },
  );

  test('cleanup이 겹쳐 와도 label마다 한 번만 지웁니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(requests),
    );
    await relay.handle('POST', '/login', {'label': 'e2eTwice'});
    requests.clear();

    final results = await Future.wait([
      relay.handle('POST', '/cleanup', null),
      relay.handle('POST', '/cleanup', null),
    ]);

    expect(results.map((r) => jsonDecode(r.body)), [
      {'deleted': 1, 'failed': <String>[]},
      {'deleted': 0, 'failed': <String>[]},
    ]);
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /test/v1/auth/login',
      'DELETE /v1/me',
    ]);
  });

  test('server 4xx는 상태와 본문을 그대로 돌려줍니다', () async {
    const problem = '{"code":"birth.invalid","title":"Unprocessable"}';
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(
        requests,
        override: (request) => request.url.path == '/v1/me/profile'
            ? http.Response(
                problem,
                422,
                headers: {'content-type': 'application/problem+json'},
              )
            : null,
      ),
    );

    final login = await StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: MockClient((_) async => http.Response('{"code":"x"}', 404)),
    ).handle('POST', '/login', {'label': 'e2eNo'});
    final session = await relay.handle('POST', '/session', {
      'label': 'e2eErr',
      'profile': true,
    });

    expect(login.status, 404);
    expect(login.body, '{"code":"x"}');
    expect(session.status, 422);
    expect(session.body, problem);
    expect(session.contentType, 'application/problem+json');
  });

  test('server 오류 본문은 charset이 없어도 바이트 그대로 돌려줍니다', () async {
    const problem = '{"code":"birth.invalid","title":"생년월일이 올바르지 않습니다"}';
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(problem),
          422,
          headers: {'content-type': 'application/problem+json'},
        ),
      ),
    );

    final response = await relay.handle('POST', '/login', {'label': 'e2eKo'});

    expect(response.status, 422);
    expect(response.bytes, utf8.encode(problem));
    expect(response.contentType, 'application/problem+json');
  });

  test('2xx인데 모양이 다른 응답은 502이고, cleanup은 실패 label로 남깁니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(
        requests,
        override: (request) => request.url.path == '/test/v1/auth/login'
            ? http.Response('{"isNewAccount":true}', 200)
            : null,
      ),
    );

    final session = await relay.handle('POST', '/session', {'label': 'e2eOdd'});
    final cleanup = await relay.handle('POST', '/cleanup', null);

    expect(session.status, 502);
    expect(jsonDecode(cleanup.body), {
      'deleted': 0,
      'failed': ['e2eOdd'],
    });
    expect(relay.labels, {'e2eOdd'});
  });

  test('cleanup은 한 label의 모양이 다른 응답 뒤에도 남은 label을 지웁니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(
        requests,
        override: (request) =>
            request.url.path == '/test/v1/auth/login' &&
                request.body.contains('e2eOdd')
            ? http.Response('{"tokens":{}}', 200)
            : null,
      ),
    );
    await relay.handle('POST', '/login', {'label': 'e2eOdd'});
    await relay.handle('POST', '/login', {'label': 'e2eGood'});

    final cleanup = await relay.handle('POST', '/cleanup', null);

    expect(jsonDecode(cleanup.body), {
      'deleted': 1,
      'failed': ['e2eOdd'],
    });
  });

  test(
    'session은 consentRequired인데 requiredConsents가 비면 동의 요청 없이 이어 갑니다',
    () async {
      final requests = <http.Request>[];
      final relay = StagingRelay(
        apiBase: apiBase,
        secret: secret,
        client: stagingServer(
          requests,
          override: (request) => request.url.path == '/v1/me'
              ? http.Response(
                  '{"accountId":"a","consentRequired":true,'
                  '"requiredConsents":[]}',
                  200,
                )
              : null,
        ),
      );

      final response = await relay.handle('POST', '/session', {
        'label': 'e2eNone',
        'profile': true,
      });

      expect(response.status, 200);
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /test/v1/auth/login',
        'GET /v1/me',
        'PUT /v1/me/profile',
      ]);
    },
  );

  test('session은 consentRequired인데 requiredConsents가 없으면 502입니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(
        requests,
        override: (request) => request.url.path == '/v1/me'
            ? http.Response('{"accountId":"a","consentRequired":true}', 200)
            : null,
      ),
    );

    final response = await relay.handle('POST', '/session', {
      'label': 'e2eMiss',
    });

    expect(response.status, 502);
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /test/v1/auth/login',
      'GET /v1/me',
    ]);
  });

  test('staging이 답하지 않으면 timeout 뒤 502이고, cleanup은 실패 label로 남깁니다', () async {
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 20),
    );

    final login = await relay.handle('POST', '/login', {'label': 'e2eSlow'});
    final cleanup = await relay.handle('POST', '/cleanup', null);

    expect(login.status, 502);
    expect(jsonDecode(cleanup.body), {
      'deleted': 0,
      'failed': ['e2eSlow'],
    });
  });

  test('staging 요청의 기본 timeout은 20초입니다', () {
    expect(stagingRequestTimeout, const Duration(seconds: 20));
  });

  test('staging에 닿지 못하면 502이고 예외 내용을 싣지 않습니다', () async {
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: MockClient(
        (_) async => throw http.ClientException('연결 실패 $secret'),
      ),
    );

    final response = await relay.handle('POST', '/login', {'label': 'e2eNet'});

    expect(response.status, 502);
    expect(response.body, isNot(contains(secret)));
    expect(relay.labels, {'e2eNet'});
  });

  test('ready는 200이고 모르는 경로는 404입니다', () async {
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: secret,
      client: stagingServer(requests),
    );

    final ready = await relay.handle('GET', '/ready', null);
    final unknown = await relay.handle('GET', '/login', null);

    expect(ready.status, 200);
    expect(jsonDecode(ready.body), {'ok': true});
    expect(unknown.status, 404);
    expect(requests, isEmpty);
  });

  test('로그 줄에 비밀, 토큰, 본문이 없습니다', () async {
    const longSecret = 'secret-value-123';
    final lines = <String>[];
    final requests = <http.Request>[];
    final relay = StagingRelay(
      apiBase: apiBase,
      secret: longSecret,
      client: stagingServer(
        requests,
        override: (request) => request.url.path == '/v1/me/profile'
            ? http.Response('{"code":"birth.invalid"}', 422)
            : null,
      ),
      log: lines.add,
    );

    await relay.handle('GET', '/ready', null);
    await relay.handle('POST', '/login', {'label': 'e2eLog'});
    await relay.handle('POST', '/session', {
      'label': 'e2eLog',
      'adFreeDays': 3,
    });
    await relay.handle('POST', '/session', {
      'label': 'e2eLog',
      'profile': true,
    });
    await relay.handle('POST', '/cleanup', null);

    expect(lines, [
      'GET /ready → 200',
      'POST /login → 200',
      'POST /session → 200',
      'POST /session → 422 (PUT /v1/me/profile)',
      'POST /cleanup → 200',
    ]);
    final joined = lines.join('\n');
    for (final leak in [
      longSecret,
      'access-e2eLog',
      'refresh-e2eLog',
      'birth.invalid',
      '7b0c7d1e',
      '별님',
    ]) {
      expect(joined, isNot(contains(leak)), reason: leak);
    }
  });
}
