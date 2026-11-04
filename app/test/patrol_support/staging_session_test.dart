import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/api/interceptors/auth.dart'
    show skipAuthExtra;
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';

import '../../patrol_test/support/staging_session.dart';

/// [interceptor]에 [options]를 넣고, 다음 단계로 넘어간 요청을 돌려줍니다.
RequestOptions _intercept(
  RelayLoginInterceptor interceptor,
  RequestOptions options,
) {
  final handler = _CapturingHandler();
  interceptor.onRequest(options, handler);
  final passed = handler.passed;
  if (passed == null) fail('요청이 다음 단계로 넘어가지 않았습니다');
  return passed;
}

/// `next`로 넘긴 요청을 잡아 두는 handler입니다.
final class _CapturingHandler extends RequestInterceptorHandler {
  RequestOptions? passed;

  @override
  void next(RequestOptions requestOptions) => passed = requestOptions;
}

/// 요청마다 [respond]의 결과를 돌려주는 relay 대역 adapter입니다.
final class _RelayAdapter implements HttpClientAdapter {
  new(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  @override
  void close({bool force = false}) {}
}

/// 요청을 보내면 Dio가 감싸지 않은 예외([StateError])를 던지는 Dio입니다.
final class _BrokenDio extends DioMixin {
  new() {
    options = BaseOptions(baseUrl: relayBaseUrl);
  }

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) =>
      throw StateError('broken');
}

/// [respond]로 답하는 relay Dio입니다.
Dio _relayDio(Future<ResponseBody> Function(RequestOptions) respond) =>
    Dio(BaseOptions(baseUrl: relayBaseUrl))
      ..httpClientAdapter = _RelayAdapter(respond);

void main() {
  test('label은 e2e로 시작하는 영숫자 32자 이하입니다', () {
    final label = newRelayLabel(
      now: DateTime.utc(2026, 11, 4),
      random: Random(1),
    );
    expect(label, matches(RegExp(r'^e2e[0-9]+[A-Za-z0-9]{4}$')));
    expect(label.length, lessThanOrEqualTo(32));
    expect(
      label,
      startsWith('e2e${DateTime.utc(2026, 11, 4).millisecondsSinceEpoch}'),
    );
  });

  test('label은 부를 때마다 달라 같은 실행의 계정이 겹치지 않습니다', () {
    final random = Random(1);
    final now = DateTime.utc(2026, 11, 4);
    expect(
      newRelayLabel(now: now, random: random),
      isNot(newRelayLabel(now: now, random: random)),
    );
  });

  test('시나리오마다 staging 준비가 정해져 있고 모르는 시나리오는 오류입니다', () {
    expect(stagingSetupFor('new-user'), isA<NoSession>());
    expect(stagingSetupFor('overseas'), isA<NoSession>());
    expect(stagingSetupFor('returning-user'), isA<ExistingMember>());
    for (final scenario in ['member', 'reward-unlock']) {
      expect(
        stagingSetupFor(scenario),
        isA<SignedInMember>().having((s) => s.adFreeDays, 'adFreeDays', 0),
        reason: scenario,
      );
    }
    expect(
      stagingSetupFor('evidence-unlocked'),
      isA<SignedInMember>().having((s) => s.adFreeDays, 'adFreeDays', 1),
    );
    expect(() => stagingSetupFor('no-such'), throwsArgumentError);
  });

  group('RelayLoginInterceptor', () {
    const label = 'e2e1793750400000abcd';
    final interceptor = RelayLoginInterceptor(label);

    test('로그인 네 경로만 relay로 돌립니다', () {
      for (final provider in ['kakao', 'line', 'google', 'apple']) {
        final passed = _intercept(
          interceptor,
          RequestOptions(
            path: '/v1/auth/$provider',
            method: 'POST',
            baseUrl: 'https://staging.example',
            data: {'idToken': 'provider-token'},
            headers: {'Accept-Language': 'ko', 'X-Firebase-AppCheck': 't'},
          ),
        );
        expect(passed.baseUrl, 'http://127.0.0.1:47283', reason: provider);
        expect(passed.path, '/login', reason: provider);
        expect(passed.uri.toString(), 'http://127.0.0.1:47283/login');
        expect(passed.data, {'label': label}, reason: provider);
        expect(passed.headers.keys.map((k) => k.toLowerCase()), [
          'content-type',
        ], reason: provider);
        expect(passed.contentType, Headers.jsonContentType, reason: provider);
        expect(passed.extra[skipAuthExtra], isTrue, reason: provider);
      }
    });

    test('refresh, logout, apple/web, apple/callback, GET은 그대로 둡니다', () {
      final untouched = [
        ('POST', '/v1/auth/refresh'),
        ('POST', '/v1/auth/logout'),
        ('POST', '/v1/auth/apple/web'),
        ('POST', '/v1/auth/apple/callback'),
        ('GET', '/v1/auth/kakao'),
        ('POST', '/v1/me/consents'),
      ];
      for (final (method, path) in untouched) {
        final passed = _intercept(
          interceptor,
          RequestOptions(
            path: path,
            method: method,
            baseUrl: 'https://staging.example',
            data: {'refreshToken': 'r'},
          ),
        );
        expect(passed.baseUrl, 'https://staging.example', reason: path);
        expect(passed.path, path, reason: path);
        expect(passed.data, {'refreshToken': 'r'}, reason: path);
        expect(passed.extra.containsKey(skipAuthExtra), isFalse, reason: path);
      }
    });
  });

  test('건너뛰는 provider와 대역으로 채우는 provider가 같습니다', () {
    expect(
      stagingReplacements.map((o) => o.origin).toSet(),
      stagingReplacedProviders,
    );
    expect(stagingReplacements, hasLength(stagingReplacedProviders.length));
  });

  test('e2eToday는 앱의 오늘(시계와 프로필 시간대)을 따릅니다', () {
    // UTC로는 10월 31일이지만 서울은 이미 11월 1일입니다(달 경계).
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(
          FixedClock(DateTime.utc(2026, 10, 31, 16)),
        ),
        profileTimezoneProvider.overrideWithValue('Asia/Seoul'),
      ],
    );
    addTearDown(container.dispose);
    expect(e2eToday(container), CalendarDate(2026, 11, 1));
  });

  group('relayDioOverride', () {
    test('Dio가 다시 만들어져도 새 Dio에 relay interceptor가 있습니다', () {
      final container = ProviderContainer(
        overrides: [
          apiModeProvider.overrideWithValue(ApiMode.http),
          relayDioOverride('e2e1abcd'),
        ],
      );
      addTearDown(container.dispose);
      final first = container.read(dioProvider);

      container.invalidate(tokenStoreProvider);
      final rebuilt = container.read(dioProvider);

      expect(rebuilt, isNot(same(first)));
      expect(rebuilt.interceptors.first, isA<RelayLoginInterceptor>());
    });
  });

  group('expectRelayReady', () {
    Future<ResponseBody> answer(int status) async =>
        ResponseBody.fromString('{}', status);

    test('200이면 통과합니다', () async {
      await expectRelayReady(_relayDio((_) => answer(200)));
    });

    Matcher notReady(String cause) => throwsA(
      isA<StateError>().having(
        (e) => e.message,
        'message',
        'relay 준비 안 됨: tool/patrol_staging.sh로 실행 ($cause)',
      ),
    );

    test('relay가 200이 아닌 상태로 답하면 상태 코드를 붙입니다', () {
      expect(
        expectRelayReady(_relayDio((_) => answer(503))),
        notReady('status 503'),
      );
    });

    test('relay에 닿지 못하면 DioExceptionType 이름을 붙입니다', () {
      expect(
        expectRelayReady(
          _relayDio(
            (options) => throw DioException.connectionError(
              requestOptions: options,
              reason: 'refused',
            ),
          ),
        ),
        notReady('connectionError'),
      );
    });

    test('답이 없으면 timeout을 붙입니다', () {
      expect(
        expectRelayReady(
          _relayDio((_) => Completer<ResponseBody>().future),
          timeout: const Duration(milliseconds: 50),
        ),
        notReady('timeout'),
      );
    });

    test('그 밖의 예외도 형식 이름을 붙여 같은 오류로 끝냅니다', () {
      expect(expectRelayReady(_BrokenDio()), notReady('StateError'));
    });
  });
}
