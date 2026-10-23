import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/features/purchase/application/ad_free_controller.dart';

import '../../support/app_harness.dart';

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Interceptor _unavailableRestore() => InterceptorsWrapper(
  onRequest: (options, handler) {
    if (options.path != '/v1/billing/restore') {
      handler.next(options);
      return;
    }
    handler.reject(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 503,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
          data: <String, Object?>{
            'status': 503,
            'code': 'billing.provider_unavailable',
            'traceId': 't',
          },
        ),
      ),
      true,
    );
  },
);

Future<ProviderContainer> _start(
  Purchases purchases, {
  Interceptor? network,
  bool listen = true,
}) async {
  final container = await bootstrapForTest(
    'member',
    overrides: [purchasesProvider.overrideWithValue(purchases)],
  );
  addTearDown(container.dispose);
  await container.read(entryStateProvider.future);
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  if (listen) {
    final subscription = container.listen(adFreeControllerProvider, (_, _) {});
    addTearDown(subscription.close);
  }
  return container;
}

List<String> _recordHaptics() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

/// 구매 결과를 [gate]가 열릴 때까지 붙잡는 대역. 호출은 [inner]에 모읍니다.
final class _SlowPurchases implements Purchases {
  new(this.gate);

  final Completer<void> gate;
  final inner = FakePurchases();

  @override
  Future<void> logIn(String accountId) => inner.logIn(accountId);

  @override
  Future<void> logOut() => inner.logOut();

  @override
  Future<void> sync() => inner.sync();

  @override
  Future<List<StoreProduct>> products() => inner.products();

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    final outcome = await inner.buy(productId);
    await gate.future;
    return outcome;
  }
}

FakeCrashReporter _crashOf(ProviderContainer container) =>
    container.read(crashReporterProvider) as FakeCrashReporter;

/// 계약을 어기고 buy에서 예외를 던지는 대역.
final class _ThrowingPurchases implements Purchases {
  @override
  Future<void> logIn(String accountId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<void> sync() async {}

  @override
  Future<List<StoreProduct>> products() async => const [];

  @override
  Future<PurchaseOutcome> buy(String productId) async =>
      throw StateError('product ad_free_1month');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('성공이면 햅틱 light, restorePurchases, getMe 다시 받기', () async {
    final haptics = _recordHaptics();
    final container = await _start(FakePurchases());
    final getMeBefore = _fake(container).callCountOf('getMe');

    final outcome = await container
        .read(adFreeControllerProvider.notifier)
        .buy(fakeAdFreeProductId);

    expect(outcome, isA<PurchaseSucceeded>());
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(_fake(container).callCountOf('restorePurchases'), 1);
    expect(_fake(container).callCountOf('getMe'), getMeBefore + 1);
    expect(container.read(adFreeControllerProvider), isFalse);
  });

  test('restorePurchases가 503이어도 성공을 돌려주고 getMe는 부른다', () async {
    final container = await _start(
      FakePurchases(),
      network: _unavailableRestore(),
    );
    final getMeBefore = _fake(container).callCountOf('getMe');

    final outcome = await container
        .read(adFreeControllerProvider.notifier)
        .buy(fakeAdFreeProductId);

    expect(outcome, isA<PurchaseSucceeded>());
    expect(_fake(container).callCountOf('getMe'), getMeBefore + 1);
    // 503은 서버 장애로 알려진 오류라 crash 기록을 남기지 않습니다.
    expect(_crashOf(container).errors, isEmpty);
  });

  test('취소면 아무것도 부르지 않는다', () async {
    final haptics = _recordHaptics();
    final container = await _start(
      FakePurchases(outcomes: const [PurchaseCancelled()]),
    );
    final getMeBefore = _fake(container).callCountOf('getMe');

    final outcome = await container
        .read(adFreeControllerProvider.notifier)
        .buy(fakeAdFreeProductId);

    expect(outcome, isA<PurchaseCancelled>());
    expect(haptics, isEmpty);
    expect(_fake(container).callCountOf('restorePurchases'), 0);
    expect(_fake(container).callCountOf('getMe'), getMeBefore);
  });

  test('실패면 PurchaseFailed를 돌려준다', () async {
    final container = await _start(
      FakePurchases(outcomes: const [PurchaseFailed(OfflineError())]),
    );

    final outcome = await container
        .read(adFreeControllerProvider.notifier)
        .buy(fakeAdFreeProductId);

    expect(outcome, isA<PurchaseFailed>());
    expect((outcome as PurchaseFailed).error, isA<OfflineError>());
    expect(_fake(container).callCountOf('restorePurchases'), 0);
  });

  test('구매 중 다시 부르면 buy를 다시 부르지 않는다', () async {
    final gate = Completer<void>();
    final purchases = _SlowPurchases(gate);
    final container = await _start(purchases);
    final controller = container.read(adFreeControllerProvider.notifier);

    final first = controller.buy(fakeAdFreeProductId);
    final second = controller.buy(fakeAdFreeProductId);
    expect(container.read(adFreeControllerProvider), isTrue);
    gate.complete();

    expect(await second, isA<PurchaseSucceeded>());
    expect(await first, isA<PurchaseSucceeded>());
    expect(purchases.inner.buyCalls, 1);
    expect(_fake(container).callCountOf('restorePurchases'), 1);
  });

  test('구매 중 화면을 떠나도(구독 해제) 장부 맞추기와 getMe가 끝까지 간다', () async {
    final gate = Completer<void>();
    final container = await _start(_SlowPurchases(gate), listen: false);
    final subscription = container.listen(adFreeControllerProvider, (_, _) {});
    final getMeBefore = _fake(container).callCountOf('getMe');
    final pending = container
        .read(adFreeControllerProvider.notifier)
        .buy(fakeAdFreeProductId);

    subscription.close();
    await Future<void>.delayed(Duration.zero);
    gate.complete();

    expect(await pending, isA<PurchaseSucceeded>());
    expect(_fake(container).callCountOf('restorePurchases'), 1);
    expect(_fake(container).callCountOf('getMe'), getMeBefore + 1);
  });

  test('buy가 예상 밖 예외를 던지면 crash 요약을 남기고 PurchaseFailed로 감싼다', () async {
    final container = await _start(_ThrowingPurchases());

    final outcome = await container
        .read(adFreeControllerProvider.notifier)
        .buy(fakeAdFreeProductId);

    expect(outcome, isA<PurchaseFailed>());
    expect((outcome as PurchaseFailed).error, isA<UnexpectedError>());
    expect(_crashOf(container).errors, hasLength(1));
    expect(container.read(adFreeControllerProvider), isFalse);
  });
}
