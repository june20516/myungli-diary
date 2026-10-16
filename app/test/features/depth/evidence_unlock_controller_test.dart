import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/entitlements.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/monetization/application/entitlements_providers.dart';
import 'package:myungli_diary/features/monetization/data/entitlements_repository.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

import '../../support/app_harness.dart';

/// 열림을 기대하는 테스트의 확인 간격·시간: 간격은 짧고 마감은 깁니다.
///
/// 마감은 가짜 시계로 흐르고 대역 서버 응답은 실제 I/O라, 마감이 짧으면 응답보다 먼저
/// 지나 테스트가 흔들립니다.
const ({Duration interval, Duration timeout}) _timing = (
  interval: Duration(milliseconds: 100),
  timeout: Duration(minutes: 10),
);

/// 마감을 실제로 기다리는 테스트의 확인 간격·시간.
const ({Duration interval, Duration timeout}) _expiringTiming = (
  interval: Duration(milliseconds: 100),
  timeout: Duration(seconds: 1),
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

/// 이 계정의 `locked` 달력 캐시가 모두 지워질 때까지 기다립니다. 끝나지 않으면 실패합니다.
Future<void> _untilCalendarUnlocked(
  WidgetTester tester,
  CacheStore cache,
) async {
  for (var i = 0; i < 300; i++) {
    final locked = await tester.runAsync(
      () => cache.lockedKeys(CacheKind.calendar),
    );
    if (locked!.isEmpty) {
      return;
    }
    await _spin(tester);
  }
  fail('locked 달력 캐시가 남아 있음');
}

/// 달력 캐시에 `locked` 달 하나를 심습니다.
Future<void> _seedLockedCalendar(WidgetTester tester, CacheStore cache) =>
    tester
        .runAsync(
          () => cache.write(
            CacheKind.calendar,
            'fp|ko|2026-10',
            '{}',
            access: EvidenceAccess.locked,
          ),
        )
        .then((_) {});

/// [scenario]로 부팅해 오늘 응답을 받아 둡니다(근거 시트는 오늘 화면에서 열리므로).
Future<ProviderContainer> _boot(
  WidgetTester tester, {
  String scenario = 'member',
  ({Duration interval, Duration timeout}) timing = _timing,
  List<Override> overrides = const [],
}) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(
      scenario,
      overrides: [
        rewardPollTimingProvider.overrideWithValue(timing),
        ...overrides,
      ],
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

/// `/v1/me/entitlements`를 [armed] 뒤부터 [release]될 때까지 붙잡고 들어온 수를 셉니다.
final class _HoldEntitlements extends Interceptor {
  bool armed = false;
  int calls = 0;
  final _release = Completer<void>();

  void release() => _release.complete();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (armed && options.path == '/v1/me/entitlements') {
      calls++;
      await _release.future;
    }
    handler.next(options);
  }
}

/// `/v1/me/entitlements`를 근거 열람 권한이 있는 응답으로 답하고 수를 셉니다.
final class _InsightActive extends Interceptor {
  int calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path != '/v1/me/entitlements') {
      handler.next(options);
      return;
    }
    calls++;
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/json'],
        }),
        data: {
          'adFree': {'active': false},
          'insight': {
            'active': true,
            'expiresAt': '2026-10-13T15:00:00Z',
            'source': 'rewarded_ad',
          },
        },
      ),
      true,
    );
  }
}

void _insertBeforeFake(ProviderContainer container, Interceptor interceptor) {
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, interceptor);
}

/// 이용권 응답을 손으로 정하는 API 대역. [answers]를 차례로 돌려주고, 함수가 던지면 그대로 던집니다.
final class _ScriptedApi extends DefaultApi {
  new(this.answers) : super(Dio());

  final List<Entitlements Function()> answers;
  int calls = 0;

  @override
  Future<Response<Entitlements>> getEntitlements({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final answer = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    return Response(
      requestOptions: RequestOptions(path: '/v1/me/entitlements'),
      statusCode: 200,
      data: answer(),
    );
  }
}

Entitlements _inactive() => Entitlements(
  adFree: AdFree(active: false),
  insight: Insight(active: false),
);

/// 보상형 광고 불러오기가 [error]를 던지는 대역. 불러온 횟수를 셉니다.
final class _ThrowingAds implements Ads {
  new(this.error);

  final Object error;

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async => null;

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) =>
      Future.error(error);
}

/// 보상형 광고를 [result]가 끝날 때까지 보여 주는 대역.
final class _GatedAds implements Ads {
  final result = Completer<RewardedResult>();

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async => null;

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) async =>
      _GatedAd(result.future);
}

final class _GatedAd implements RewardedAdHandle {
  new(this._result);

  final Future<RewardedResult> _result;

  @override
  Future<RewardedResult> show() => _result;
}

/// 손으로 바꾸는 근거 열람 상태(계획 6의 다른 응답을 흉내 냄).
final class _Access extends Notifier<AsyncValue<EvidenceAccess>> {
  @override
  AsyncValue<EvidenceAccess> build() => const AsyncData(EvidenceAccess.locked);

  void change(EvidenceAccess access) => state = AsyncData(access);
}

final _accessProvider = NotifierProvider<_Access, AsyncValue<EvidenceAccess>>(
  _Access.new,
);

/// 근거가 없는 응답의 근거 목록.
final _noEvidenceProvider = Provider<AsyncValue<List<Evidence>>>(
  (ref) => const AsyncData([]),
);

/// 오늘 그런 이유가 없는 응답의 문장.
final _noReasonProvider = Provider<RenderedText?>((ref) => null);

/// [_accessProvider]를 근거로 보는 응답. 다시 받기는 아무것도 하지 않습니다.
@immutable
final class _TestSubject implements EvidenceSubject {
  const new();

  @override
  ProviderListenable<AsyncValue<EvidenceAccess>> get access => _accessProvider;

  @override
  ProviderListenable<AsyncValue<List<Evidence>>> evidenceOf(String slotId) =>
      _noEvidenceProvider;

  @override
  ProviderListenable<RenderedText?> todayReasonOf(String slotId) =>
      _noReasonProvider;

  @override
  Future<void> reload(Ref ref) async {}

  @override
  bool operator ==(Object other) => other is _TestSubject;

  @override
  int get hashCode => (_TestSubject).hashCode;
}

final NotifierProvider<EvidenceUnlockController, EvidenceUnlockState>
_testProvider = evidenceUnlockControllerProvider(const _TestSubject());

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

    testWidgets('시트가 닫혀 버려지면 이벤트 통로를 닫습니다', (tester) async {
      final container = await _boot(tester);
      final opened = _open(container);
      var closed = false;
      final done = container
          .read(_provider.notifier)
          .events
          .listen(null, onDone: () => closed = true);
      addTearDown(done.cancel);
      await _prepared(tester, container);
      expect(closed, isFalse);

      opened.subscription.close();
      await _spin(tester);

      expect(container.exists(_provider), isFalse);
      expect(closed, isTrue);
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

    testWidgets('잠금 해제에 성공하면 locked로 받은 달력 캐시를 버린다(A32)', (tester) async {
      final container = await _boot(tester, scenario: 'reward-unlock');
      final cache = container.read(cacheStoreProvider);
      await tester.runAsync(() async {
        await cache.write(
          CacheKind.calendar,
          'fp|ko|2026-10',
          '{}',
          access: EvidenceAccess.locked,
        );
        await cache.write(
          CacheKind.calendar,
          'fp|ko|2026-11',
          '{}',
          access: EvidenceAccess.unlocked,
        );
      });
      _open(container);
      await _prepared(tester, container);

      unawaited(container.read(_provider.notifier).watchAd());
      await _until(
        tester,
        () => _state(container).link == DepthLinkState.unlocked,
      );
      await _untilCalendarUnlocked(tester, cache);

      final kept = await tester.runAsync(
        () => cache.read(CacheKind.calendar, 'fp|ko|2026-11'),
      );
      expect(kept, isNotNull);
    });

    testWidgets('시트를 열 때 이미 unlocked여도 locked 달력 캐시를 버린다(A32)', (tester) async {
      final container = await _boot(tester, scenario: 'evidence-unlocked');
      final cache = container.read(cacheStoreProvider);
      await _seedLockedCalendar(tester, cache);

      _open(container);

      expect(_state(container).link, DepthLinkState.unlocked);
      await _untilCalendarUnlocked(tester, cache);
    });

    testWidgets('30초 안에 권한이 없으면 UnlockTimedOut과 locked', (tester) async {
      final container = await _boot(
        tester,
        scenario: 'reward-timeout',
        timing: _expiringTiming,
      );
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
          _expiringTiming.timeout.inMilliseconds ~/
              _expiringTiming.interval.inMilliseconds,
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

  group('수정 라운드 1', () {
    testWidgets('요청이 늦어도 마감 시각(30초)에 UnlockTimedOut이고 마감 뒤에는 더 묻지 않는다', (
      tester,
    ) async {
      final container = await _boot(
        tester,
        scenario: 'reward-timeout',
        timing: (interval: rewardPollInterval, timeout: rewardPollTimeout),
      );
      final opened = _open(container);
      await _prepared(tester, container);
      final hold = _HoldEntitlements();
      _insertBeforeFake(container, hold);
      hold.armed = true;

      unawaited(container.read(_provider.notifier).watchAd());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(hold.calls, 1, reason: '첫 확인 요청이 응답 없이 붙잡힘');
      await tester.pump(const Duration(seconds: 27));
      expect(opened.events, isEmpty);
      expect(_state(container).link, DepthLinkState.unlocking);

      await tester.pump(const Duration(seconds: 1));
      expect(opened.events.single, isA<UnlockTimedOut>());
      expect(_state(container).link, DepthLinkState.locked);

      await tester.pump(const Duration(seconds: 10));
      expect(hold.calls, 1, reason: '마감 뒤에는 묻지 않음');
      hold.release();
      await _spin(tester);
    });

    testWidgets('열 때 권한이 있는데 다시 받은 응답이 잠겨 있으면 조용히 locked(toast 없음, 반복 없음)', (
      tester,
    ) async {
      final container = await _boot(tester);
      final active = _InsightActive();
      _insertBeforeFake(container, active);
      final dailyBefore = _dailyCalls(container);

      final opened = _open(container);
      await _until(tester, () => _state(container).adReady);
      for (var i = 0; i < 10; i++) {
        await _spin(tester);
      }

      expect(opened.events, isEmpty, reason: '광고를 보지 않았으므로 확인 실패를 알리지 않음');
      expect(_state(container).link, DepthLinkState.locked);
      expect(_state(container).adReady, isTrue);
      expect(active.calls, 1);
      expect(_dailyCalls(container), dailyBefore + 1);
    });

    testWidgets('다시 받기에 실패해도 오늘 값은 이전 AsyncData 그대로입니다', (tester) async {
      final container = await _boot(tester, scenario: 'reward-unlock');
      _open(container);
      await _prepared(tester, container);
      final before = container.read(dailyControllerProvider).value;
      _insertBeforeFake(container, _FailDailyOnce());

      unawaited(container.read(_provider.notifier).watchAd());
      await _until(tester, () => _state(container).refreshError != null);

      final daily = container.read(dailyControllerProvider);
      expect(daily.hasError, isFalse, reason: '오류는 시트만 보임');
      expect(daily.isLoading, isFalse);
      expect(identical(daily.value, before), isTrue);
    });

    testWidgets('광고 불러오기의 AppError는 보고 없이 lockedNoAd', (tester) async {
      final reporter = FakeCrashReporter();
      final container = await _boot(
        tester,
        overrides: [
          adsProvider.overrideWithValue(_ThrowingAds(const OfflineError())),
          crashReporterProvider.overrideWithValue(reporter),
        ],
      );
      _open(container);
      await _prepared(tester, container);

      expect(_state(container).link, DepthLinkState.lockedNoAd);
      expect(reporter.errors, isEmpty);
    });

    testWidgets('광고 불러오기의 예상 밖 예외는 보고하고 lockedNoAd', (tester) async {
      final reporter = FakeCrashReporter();
      final container = await _boot(
        tester,
        overrides: [
          adsProvider.overrideWithValue(_ThrowingAds(StateError('sdk'))),
          crashReporterProvider.overrideWithValue(reporter),
        ],
      );
      _open(container);
      await _prepared(tester, container);

      expect(_state(container).link, DepthLinkState.lockedNoAd);
      expect(reporter.errors, hasLength(1));
    });

    testWidgets('이용권 확인의 예상 밖 예외: 열 때는 조용히, 광고 뒤에는 보고·locked·UnlockFailed', (
      tester,
    ) async {
      final reporter = FakeCrashReporter();
      final api = _ScriptedApi([() => throw StateError('예상 밖')]);
      final container = await _boot(
        tester,
        overrides: [
          entitlementsRepositoryProvider.overrideWithValue(
            EntitlementsRepository(api),
          ),
          crashReporterProvider.overrideWithValue(reporter),
        ],
      );
      final opened = _open(container);
      await _until(tester, () => _state(container).adReady && api.calls == 1);
      await _spin(tester);
      expect(opened.events, isEmpty);
      expect(reporter.errors, hasLength(1));

      unawaited(container.read(_provider.notifier).watchAd());
      await _until(tester, () => opened.events.isNotEmpty);

      expect(opened.events.single, isA<UnlockFailed>());
      expect(
        (opened.events.single as UnlockFailed).error,
        isA<UnexpectedError>(),
      );
      expect(_state(container).link, DepthLinkState.locked);
      expect(reporter.errors, hasLength(2));
      expect(api.calls, 2, reason: '실패 뒤 더 묻지 않음');
    });

    testWidgets('이미 불러 둔 광고가 있으면 다시 준비할 때 또 부르지 않습니다', (tester) async {
      final ads = FakeAds();
      final container = await _boot(
        tester,
        overrides: [
          adsProvider.overrideWithValue(ads),
          entitlementsRepositoryProvider.overrideWithValue(
            EntitlementsRepository(_ScriptedApi([_inactive])),
          ),
        ],
      );
      container.listen(_testProvider, (_, _) {});
      await _until(tester, () => container.read(_testProvider).adReady);
      expect(ads.rewardedUserIds, hasLength(1));

      // 다른 길로 열렸다가(광고는 그대로 쥐고 있음) 새 날짜처럼 다시 잠깁니다.
      container.read(_accessProvider.notifier).change(EvidenceAccess.unlocked);
      expect(container.read(_testProvider).link, DepthLinkState.unlocked);
      container.read(_accessProvider.notifier).change(EvidenceAccess.locked);
      await _until(tester, () => container.read(_testProvider).adReady);
      for (var i = 0; i < 3; i++) {
        await _spin(tester);
      }

      expect(ads.rewardedUserIds, hasLength(1));
    });

    testWidgets('확인 중에 다른 길로 열리면 watchAd도 끝납니다', (tester) async {
      final container = await _boot(
        tester,
        timing: (interval: rewardPollInterval, timeout: rewardPollTimeout),
        overrides: [
          entitlementsRepositoryProvider.overrideWithValue(
            EntitlementsRepository(_ScriptedApi([_inactive])),
          ),
        ],
      );
      container.listen(_testProvider, (_, _) {});
      await _until(tester, () => container.read(_testProvider).adReady);

      var finished = false;
      unawaited(
        container
            .read(_testProvider.notifier)
            .watchAd()
            .whenComplete(() => finished = true),
      );
      await tester.pump();
      expect(container.read(_testProvider).link, DepthLinkState.unlocking);

      container.read(_accessProvider.notifier).change(EvidenceAccess.unlocked);
      await tester.pump();
      expect(container.read(_testProvider).link, DepthLinkState.unlocked);
      expect(finished, isTrue);
    });

    testWidgets('다른 길로 열리면 locked 달력 캐시를 버리고, 정리를 거듭 불러도 오류가 없다(A32)', (
      tester,
    ) async {
      final container = await _boot(
        tester,
        overrides: [
          entitlementsRepositoryProvider.overrideWithValue(
            EntitlementsRepository(_ScriptedApi([_inactive])),
          ),
        ],
      );
      final cache = container.read(cacheStoreProvider);
      final reporter =
          container.read(crashReporterProvider) as FakeCrashReporter;
      container.listen(_testProvider, (_, _) {});
      await _until(tester, () => container.read(_testProvider).adReady);
      await _seedLockedCalendar(tester, cache);

      container.read(_accessProvider.notifier).change(EvidenceAccess.unlocked);
      await tester.pump();
      expect(container.read(_testProvider).link, DepthLinkState.unlocked);
      await _untilCalendarUnlocked(tester, cache);

      // 거듭 불려도(잠금 해제 성공 뒤 다른 길로도 열림) 지울 것이 없을 뿐 오류가 없습니다.
      await tester.runAsync(() async {
        final sync = container.read(calendarUnlockSyncProvider);
        await sync.forgetLocked();
        await sync.forgetLocked();
      });
      expect(
        await tester.runAsync(() => cache.lockedKeys(CacheKind.calendar)),
        isEmpty,
      );
      expect(reporter.errors, isEmpty);
    });
  });

  group('수정 라운드 2', () {
    testWidgets('광고를 보는 동안 다른 길로 열리면 끝까지 봐도 다시 확인하지 않고 열린 채입니다', (
      tester,
    ) async {
      final ads = _GatedAds();
      final api = _ScriptedApi([_inactive]);
      final container = await _boot(
        tester,
        overrides: [
          adsProvider.overrideWithValue(ads),
          entitlementsRepositoryProvider.overrideWithValue(
            EntitlementsRepository(api),
          ),
        ],
      );
      container.listen(_testProvider, (_, _) {});
      final events = <UnlockEvent>[];
      container.read(_testProvider.notifier).events.listen(events.add);
      await _until(tester, () => container.read(_testProvider).adReady);
      final asked = api.calls;

      var finished = false;
      unawaited(
        container
            .read(_testProvider.notifier)
            .watchAd()
            .whenComplete(() => finished = true),
      );
      await tester.pump();
      container.read(_accessProvider.notifier).change(EvidenceAccess.unlocked);
      ads.result.complete(const RewardEarned());
      await tester.pump();
      await tester.pump(const Duration(minutes: 1));

      expect(finished, isTrue);
      expect(container.read(_testProvider).link, DepthLinkState.unlocked);
      expect(api.calls, asked, reason: '이미 열렸으므로 묻지 않음');
      expect(events, isEmpty);
    });
  });
}
