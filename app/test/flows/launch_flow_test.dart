import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';

/// 보내는 요청 수를 세는 interceptor. 오프라인으로 실패할 요청도 셉니다.
class _CountingInterceptor extends Interceptor {
  int requests = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests++;
    handler.next(options);
  }
}

void main() {
  Future<void> expectArrival(
    WidgetTester tester,
    String scenario,
    String screenId,
  ) async {
    await pumpApp(tester, scenario: scenario);

    expect(find.byKey(ValueKey(screenId)), findsOneWidget);
  }

  testWidgets('new-user 시나리오는 welcome 화면에 도착합니다', (tester) async {
    covers(const Covers(exits: ['launch>welcome'], decisions: ['D50']));
    await expectArrival(tester, 'new-user', ScreenIds.welcome);
  });

  testWidgets('member 시나리오는 today 화면에 도착합니다', (tester) async {
    covers(const Covers(exits: ['launch>today']));
    await expectArrival(tester, 'member', ScreenIds.today);
  });

  testWidgets('force-update 시나리오는 force-update 화면에 도착합니다', (tester) async {
    covers(const Covers(exits: ['launch>force-update']));
    await expectArrival(tester, 'force-update', ScreenIds.forceUpdate);
  });

  // 아래 두 도착은 launch의 exits에 없어 덮는 경로를 선언하지 않습니다.
  testWidgets('consent-required 시나리오는 consent 화면에 도착합니다', (tester) async {
    await expectArrival(tester, 'consent-required', ScreenIds.consent);
  });

  testWidgets('profile-required 시나리오는 onboard-call 화면에 도착합니다', (tester) async {
    await expectArrival(tester, 'profile-required', ScreenIds.onboardCall);
  });

  testWidgets('offline이고 캐시가 없으면 launch가 offline 오류와 다시 시도를 보입니다', (
    tester,
  ) async {
    covers(const Covers(states: ['launch:offline']));
    final container = await pumpApp(tester, scenario: 'offline');
    final counter = _CountingInterceptor();
    container.read(dioProvider).interceptors.insert(0, counter);

    expect(find.byKey(const ValueKey(ScreenIds.launch)), findsOneWidget);
    final errorState = tester.widget<ErrorState>(find.byType(ErrorState));
    expect(errorState.error, isA<OfflineError>());
    expect(errorState.variant, ErrorStateVariant.offline);
    expect(find.text('다시 시도'), findsOneWidget);

    // 다시 시도는 진입 계산을 다시 합니다(대역은 계속 오프라인이라 오류 그대로).
    expect(counter.requests, 0);
    await tester.tap(find.text('다시 시도'));
    await settleEntry(tester, container);
    expect(counter.requests, greaterThan(0));
    expect(container.read(entryStateProvider).hasError, isTrue);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('member는 탭 바와 하단 틀 높이를 화면에 줍니다', (tester) async {
    await pumpApp(tester, scenario: 'member');

    expect(find.byKey(const ValueKey('bottom-bar.surface')), findsOneWidget);
  });

  testWidgets('signedIn 시나리오는 refresh token으로 세션을 복원합니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'member');

    expect(container.read(tokenStoreProvider).accessToken, 'fake-access-token');
  });

  testWidgets('new-user 시나리오는 토큰이 없습니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'new-user');

    final tokens = container.read(tokenStoreProvider);
    expect(tokens.accessToken, isNull);
    expect(await tester.runAsync(tokens.refreshToken), isNull);
  });

  testWidgets('앱이 다시 앞으로 오면 오늘 날짜를 바로 다시 확인합니다', (tester) async {
    var builds = 0;
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [
        todayProvider.overrideWith((ref) {
          builds++;
          return CalendarDate(2026, 10, 13);
        }),
      ],
    );
    container.read(todayProvider);
    final before = builds;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    container.read(todayProvider);

    expect(builds, before + 1);
  });
}
