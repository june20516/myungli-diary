import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/features/purchase/application/purchase_history_controller.dart';

import '../../support/app_harness.dart';
import '../../support/purchase_stubs.dart';

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// 지정한 operation 요청을 server에 닿기 전에 실패시킵니다.
Interceptor _failing(String path, DioException Function(RequestOptions) make) =>
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == path) {
          handler.reject(make(options), true);
        } else {
          handler.next(options);
        }
      },
    );

DioException _offline(RequestOptions options) =>
    DioException.connectionError(requestOptions: options, reason: '테스트 실패');

DioException _unavailable(RequestOptions options) {
  final response = Response<Object?>(
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
  );
  return DioException.badResponse(
    statusCode: 503,
    requestOptions: options,
    response: response,
  );
}

Future<ProviderContainer> _start({
  Purchases? purchases,
  Interceptor? network,
}) async {
  final container = await bootstrapForTest(
    'ad-free-active',
    overrides: [
      if (purchases != null) purchasesProvider.overrideWithValue(purchases),
    ],
  );
  addTearDown(container.dispose);
  await container.read(entryStateProvider.future);
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  return container;
}

FakeCrashReporter _crashOf(ProviderContainer container) =>
    container.read(crashReporterProvider) as FakeCrashReporter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sync 뒤 restorePurchases 뒤 listPurchases 순서다', () async {
    final seen = <int>[];
    late ProviderContainer container;
    final purchases = FakePurchases(
      onSync: () => seen.add(_fake(container).callCountOf('restorePurchases')),
    );
    container = await _start(purchases: purchases);
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    final list = await container.read(purchaseHistoryProvider.future);

    expect(seen, [0]);
    expect(purchases.syncCalls, 1);
    expect(_fake(container).callCountOf('restorePurchases'), 1);
    expect(_fake(container).callCountOf('listPurchases'), 1);
    expect(list, hasLength(4));
  });

  test('sync가 실패해도 목록을 받고 오류를 내지 않는다', () async {
    final container = await _start(
      purchases: FakePurchases(syncFailWith: const OfflineError()),
    );
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    final list = await container.read(purchaseHistoryProvider.future);

    expect(list, hasLength(4));
    expect(_crashOf(container).errors, isEmpty);
  });

  test('restorePurchases 503이어도 목록을 받는다', () async {
    final container = await _start(
      network: _failing('/v1/billing/restore', _unavailable),
    );
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    final list = await container.read(purchaseHistoryProvider.future);

    expect(list, hasLength(4));
    expect(_crashOf(container).errors, isEmpty);
  });

  test('restorePurchases가 성공하면 getMe를 한 번 더 부른다', () async {
    final container = await _start();
    final before = _fake(container).callCountOf('getMe');
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(purchaseHistoryProvider.future);

    expect(_fake(container).callCountOf('getMe'), before + 1);
  });

  test('실패하면 getMe를 다시 부르지 않는다', () async {
    final container = await _start(
      network: _failing('/v1/billing/restore', _unavailable),
    );
    final before = _fake(container).callCountOf('getMe');
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(purchaseHistoryProvider.future);

    expect(_fake(container).callCountOf('getMe'), before);
  });

  test('예상 밖 sync 오류는 crash 기록 한 번, 구매 정보는 싣지 않는다', () async {
    final container = await _start(
      purchases: FakePurchases(
        syncFailWith: UnexpectedError(StateError('product ad_free_1month')),
      ),
    );
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(purchaseHistoryProvider.future);

    final errors = _crashOf(container).errors;
    expect(errors, hasLength(1));
    expect(errors.single.errorType, 'StateError');
    expect(errors.single.code, isNull);
    expect(errors.single.status, isNull);
  });

  test('listPurchases가 오프라인이면 AsyncError(OfflineError)', () async {
    final container = await _start(
      network: _failing('/v1/me/purchases', _offline),
    );
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    await expectLater(
      container.read(purchaseHistoryProvider.future),
      throwsA(isA<OfflineError>()),
    );
    expect(container.read(purchaseHistoryProvider).error, isA<OfflineError>());
  });

  test('retry는 sync부터 다시 한다', () async {
    final purchases = FakePurchases();
    final container = await _start(purchases: purchases);
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(purchaseHistoryProvider.future);

    await container.read(purchaseHistoryProvider.notifier).retry();

    expect(purchases.syncCalls, 2);
    expect(_fake(container).callCountOf('listPurchases'), 2);
    expect(container.read(purchaseHistoryProvider).value, hasLength(4));
  });

  test('불러오는 중 retry를 겹쳐 불러도 한 번만 다시 한다', () async {
    final purchases = FakePurchases();
    final container = await _start(purchases: purchases);
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(purchaseHistoryProvider.future);
    final notifier = container.read(purchaseHistoryProvider.notifier);

    await Future.wait([notifier.retry(), notifier.retry()]);

    expect(purchases.syncCalls, 2);
  });

  test('예상 밖 reconcile 오류는 crash 기록 한 번, code·status 없이', () async {
    final container = await _start(
      network: _failing(
        '/v1/billing/restore',
        (options) => DioException(
          requestOptions: options,
          error: StateError('product ad_free_1month'),
        ),
      ),
    );
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(purchaseHistoryProvider.future);

    final errors = _crashOf(container).errors;
    expect(errors, hasLength(1));
    expect(errors.single.code, isNull);
    expect(errors.single.status, isNull);
  });

  test('다시 시도 중 화면을 떠나도 예외 없이 끝난다', () async {
    final purchases = GatedPurchases();
    final container = await _start(purchases: purchases);
    final subscription = container.listen(purchaseHistoryProvider, (_, _) {});
    await container.read(purchaseHistoryProvider.future);
    final gate = Completer<void>();
    purchases.syncGate = gate;

    final retrying = container.read(purchaseHistoryProvider.notifier).retry();
    await Future<void>.delayed(Duration.zero);
    expect(purchases.syncCalls, 2);
    subscription.close();
    // autoDispose가 provider를 버리게 한 차례 넘깁니다.
    await Future<void>.delayed(Duration.zero);
    gate.complete();

    await expectLater(retrying, completes);
  });
}
