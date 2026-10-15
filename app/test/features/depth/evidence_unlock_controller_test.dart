import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

import '../../support/app_harness.dart';

/// 짧게 줄인 확인 간격·시간. 최대 5번 묻습니다.
const ({Duration interval, Duration timeout}) _timing = (
  interval: Duration(milliseconds: 20),
  timeout: Duration(milliseconds: 100),
);

const _subject = DailyEvidenceSubject();

final NotifierProvider<EvidenceUnlockController, EvidenceUnlockState>
_provider = evidenceUnlockControllerProvider(_subject);

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

int _entitlementCalls(ProviderContainer container) =>
    _fake(container).callCountOf('getEntitlements');

int _dailyCalls(ProviderContainer container) =>
    _fake(container).callCountOf('getDaily');

/// 실제 I/O(asset·DB)와 가짜 시계 영역의 microtask·timer를 한 번씩 풀어 줍니다.
Future<void> _spin(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// [done]이 참이 될 때까지 [_spin]합니다. 끝나지 않으면 테스트를 실패시킵니다.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300; i++) {
    if (done()) return;
    await _spin(tester);
  }
  fail('조건이 채워지지 않음');
}

/// [scenario]로 부팅해 오늘 응답을 받아 둡니다(근거 시트는 오늘 화면에서 열리므로).
Future<ProviderContainer> _boot(
  WidgetTester tester, {
  String scenario = 'member',
}) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(
      scenario,
      overrides: [rewardPollTimingProvider.overrideWithValue(_timing)],
    ),
  ))!;
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(entryStateProvider.future));
  final daily = container.listen(dailyControllerProvider, (_, _) {});
  addTearDown(daily.close);
  await _until(
    tester,
    () =>
        container.read(dailyControllerProvider).hasValue &&
        !container.read(dailyControllerProvider).isLoading,
  );
  return container;
}

/// 근거 시트가 열린 것처럼 controller를 구독하고, 받은 상태와 이벤트를 남깁니다.
({
  ProviderSubscription<EvidenceUnlockState> subscription,
  List<UnlockEvent> events,
})
_open(ProviderContainer container) {
  final subscription = container.listen(_provider, (_, _) {});
  final events = <UnlockEvent>[];
  final eventSubscription = container
      .read(_provider.notifier)
      .events
      .listen(events.add);
  addTearDown(eventSubscription.cancel);
  return (subscription: subscription, events: events);
}

/// 처음 오는 `/v1/daily/` 요청 하나만 503으로 끊습니다.
final class _FailDailyOnce extends Interceptor {
  bool _failed = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_failed || !options.path.startsWith('/v1/daily/')) {
      handler.next(options);
      return;
    }
    _failed = true;
    handler.reject(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(requestOptions: options, statusCode: 503),
      ),
      true,
    );
  }
}

EvidenceUnlockState _state(ProviderContainer container) =>
    container.read(_provider);

/// 열 때의 준비(광고 미리 불러 두기, 이용권 한 번 묻기)가 끝날 때까지 기다립니다.
///
/// 버튼이 켜지거나 광고가 없다고 정해지고, 열 때 묻는 이용권 응답까지 받은 뒤입니다.
Future<void> _prepared(WidgetTester tester, ProviderContainer container) async {
  final asked = _entitlementCalls(container);
  await _until(tester, () {
    final state = _state(container);
    return state.adReady || state.link != DepthLinkState.locked;
  });
  await _until(tester, () => _entitlementCalls(container) > asked);
  // 이용권 응답을 받아 처리하는 차례를 마저 돌립니다.
  for (var i = 0; i < 3; i++) {
    await _spin(tester);
  }
}

/// 이어진 같은 값을 하나로 줄입니다.
List<T> _distinct<T>(Iterable<T> values) => [
  for (final (i, value) in values.indexed)
    if (i == 0 || values.elementAt(i - 1) != value) value,
];

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('EvidenceUnlockController', () {
    testWidgets('응답이 unlocked면 처음부터 unlocked', (tester) async {
      final container = await _boot(tester, scenario: 'evidence-unlocked');
      _open(container);
      await _spin(tester);

      expect(_state(container).link, DepthLinkState.unlocked);
      final ads = container.read(adsProvider) as FakeAds;
      expect(ads.rewardedUserIds, isEmpty, reason: '열려 있으면 광고를 불러 두지 않습니다');
    });

    testWidgets('locked이고 광고가 없으면 lockedNoAd', (tester) async {
      final container = await _boot(tester, scenario: 'reward-unavailable');
      _open(container);
      await _prepared(tester, container);

      expect(_state(container).link, DepthLinkState.lockedNoAd);
      expect(_state(container).adReady, isFalse);
    });

    testWidgets('locked이고 광고가 준비되면 버튼이 켜집니다', (tester) async {
      final container = await _boot(tester);
      _open(container);
      expect(_state(container).link, DepthLinkState.locked);
      expect(_state(container).adReady, isFalse, reason: '불러오는 동안은 꺼짐');
      await _prepared(tester, container);

      expect(_state(container).link, DepthLinkState.locked);
      expect(_state(container).adReady, isTrue);
    });

    testWidgets('loadRewarded의 userId는 계정 id', (tester) async {
      final container = await _boot(tester);
      _open(container);
      await _prepared(tester, container);

      final ads = container.read(adsProvider) as FakeAds;
      expect(ads.rewardedUserIds, [container.read(currentAccountIdProvider)]);
    });

    testWidgets('끝까지 보면 unlocking → 권한이 생기면 getDaily를 다시 받고 unlocked', (
      tester,
    ) async {
      final container = await _boot(tester, scenario: 'reward-unlock');
      final opened = _open(container);
      await _prepared(tester, container);
      final dailyBefore = _dailyCalls(container);
      final states = <EvidenceUnlockState>[];
      container.listen(_provider, (_, next) => states.add(next));

      unawaited(container.read(_provider.notifier).watchAd());
      await _until(
        tester,
        () => _state(container).link == DepthLinkState.unlocked,
      );

      // 광고를 보는 동안 버튼 꺼짐 → 확인 중 → 다시 받는 중 skeleton → 열림 순서입니다.
      expect(
        _distinct(
          states.map(
            (s) => (link: s.link, adReady: s.adReady, refreshing: s.refreshing),
          ),
        ),
        [
          (link: DepthLinkState.locked, adReady: false, refreshing: false),
          (link: DepthLinkState.unlocking, adReady: false, refreshing: false),
          (link: DepthLinkState.unlocking, adReady: false, refreshing: true),
          (link: DepthLinkState.unlocked, adReady: false, refreshing: false),
        ],
      );
      expect(_state(container).refreshing, isFalse);
      expect(_entitlementCalls(container), 3, reason: '열 때 한 번, 확인 두 번');
      expect(_dailyCalls(container), dailyBefore + 1);
      expect(
        container.read(dailyControllerProvider).value!.daily.evidenceAccess,
        EvidenceAccess.unlocked,
      );
      expect(opened.events, isEmpty);
    });

    testWidgets('30초 안에 권한이 없으면 UnlockTimedOut과 locked', (tester) async {
      final container = await _boot(tester, scenario: 'reward-timeout');
      final opened = _open(container);
      await _prepared(tester, container);
      final before = _entitlementCalls(container);

      unawaited(container.read(_provider.notifier).watchAd());
      await _until(tester, () => opened.events.isNotEmpty);

      expect(opened.events.single, isA<UnlockTimedOut>());
      expect(_state(container).link, DepthLinkState.locked);
      final asked = _entitlementCalls(container) - before;
      expect(asked, greaterThan(0));
      expect(
        asked,
        lessThanOrEqualTo(
          _timing.timeout.inMilliseconds ~/ _timing.interval.inMilliseconds,
        ),
      );
      // 다음 시도를 위해 광고를 다시 불러 둡니다.
      await _until(tester, () => _state(container).adReady);
      expect(_state(container).adReady, isTrue);
    });

    testWidgets('기본 확인 간격은 2초, 최대 30초입니다', (tester) async {
      expect(rewardPollInterval, const Duration(seconds: 2));
      expect(rewardPollTimeout, const Duration(seconds: 30));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(rewardPollTimingProvider), (
        interval: rewardPollInterval,
        timeout: rewardPollTimeout,
      ));
    });

    testWidgets('닫으면 locked 그대로 요청 없음', (tester) async {
      final container = await _boot(tester, scenario: 'reward-dismissed');
      final opened = _open(container);
      await _prepared(tester, container);
      final before = _entitlementCalls(container);

      await tester.runAsync(() => container.read(_provider.notifier).watchAd());
      await _until(tester, () => _state(container).adReady);

      expect(_state(container).link, DepthLinkState.locked);
      expect(_entitlementCalls(container), before);
      expect(opened.events, isEmpty);
    });

    testWidgets('표시 실패면 UnlockFailed와 locked', (tester) async {
      final container = await _boot(tester, scenario: 'reward-failed');
      final opened = _open(container);
      await _prepared(tester, container);
      final before = _entitlementCalls(container);

      await tester.runAsync(() => container.read(_provider.notifier).watchAd());
      await _until(tester, () => opened.events.isNotEmpty);

      expect(opened.events.single, isA<UnlockFailed>());
      expect(_state(container).link, DepthLinkState.locked);
      expect(_entitlementCalls(container), before);
    });

    testWidgets('확인 중에 dispose되면 묻기를 멈춘다', (tester) async {
      final container = await _boot(tester, scenario: 'reward-timeout');
      final opened = _open(container);
      await _prepared(tester, container);

      unawaited(container.read(_provider.notifier).watchAd());
      await _until(
        tester,
        () => _state(container).link == DepthLinkState.unlocking,
      );
      opened.subscription.close();
      await _spin(tester);
      expect(container.exists(_provider), isFalse, reason: '시트가 닫혀 버려짐');
      final afterClose = _entitlementCalls(container);

      for (var i = 0; i < 10; i++) {
        await _spin(tester);
      }
      expect(_entitlementCalls(container), afterClose);
      expect(opened.events, isEmpty, reason: '닫힌 화면에 toast를 띄우지 않음');
    });

    testWidgets('다시 열면 server 상태대로: 이미 권한이 있으면 다시 받아 unlocked', (tester) async {
      // 권한은 생겼지만 오늘 응답은 아직 잠긴 채 받아 둔 상태(확인 중에 시트를 닫았던 경우).
      final container = await _boot(tester, scenario: 'reward-unlock');
      final fake = _fake(container);
      // 열 때 묻는 첫 응답이 비활성이므로 두 번 소모해 세 번째(활성)가 나오게 합니다.
      final first = _open(container);
      await _prepared(tester, container);
      first.subscription.close();
      await _spin(tester);
      final second = _open(container);
      await _prepared(tester, container);
      second.subscription.close();
      await _spin(tester);
      expect(fake.callCountOf('getEntitlements'), 2);

      _open(container);
      await _until(
        tester,
        () => _state(container).link == DepthLinkState.unlocked,
      );
      expect(
        container.read(dailyControllerProvider).value!.daily.evidenceAccess,
        EvidenceAccess.unlocked,
      );
    });

    testWidgets('다시 받기에 실패하면 refreshError, retry로 다시 받아 unlocked', (
      tester,
    ) async {
      final container = await _boot(tester, scenario: 'reward-unlock');
      _open(container);
      await _prepared(tester, container);
      // 다시 받는 getDaily만 한 번 실패시킵니다.
      final gate = _FailDailyOnce();
      final interceptors = container.read(dioProvider).interceptors;
      interceptors.insert(interceptors.length - 1, gate);

      unawaited(container.read(_provider.notifier).watchAd());
      await _until(tester, () => _state(container).refreshError != null);
      expect(_state(container).refreshing, isFalse);

      unawaited(container.read(_provider.notifier).retry());
      await _until(
        tester,
        () => _state(container).link == DepthLinkState.unlocked,
      );
      expect(_state(container).refreshError, isNull);
    });
  });
}
