import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
