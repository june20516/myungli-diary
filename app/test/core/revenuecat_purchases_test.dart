import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/core/platform/revenuecat_purchases.dart';

/// SDK 경계 대역. 부른 것을 기록하고, [failWith]가 있으면 그 실패를 던집니다.
class _Api implements RevenueCatApi {
  final List<String> calls = [];
  RevenueCatFailure? failWith;
  bool anonymous = false;
  int configureFailures = 0;
  List<StoreProduct> storeProducts = const [];

  Future<void> _step(String call) async {
    calls.add(call);
    if (failWith case final failure?) throw failure;
  }

  @override
  Future<void> configure(String apiKey) async {
    calls.add('configure $apiKey');
    if (configureFailures > 0) {
      configureFailures--;
      throw const RevenueCatFailure(RevenueCatFailureKind.offline, 'down');
    }
  }

  @override
  Future<void> logIn(String appUserId) => _step('logIn $appUserId');

  @override
  Future<bool> isAnonymous() async => anonymous;

  @override
  Future<void> logOut() => _step('logOut');

  @override
  Future<void> syncPurchases() => _step('sync');

  @override
  Future<List<StoreProduct>> getProducts(List<String> ids) async {
    await _step('getProducts ${ids.join(',')}');
    return storeProducts;
  }

  @override
  Future<void> purchase(String productId) => _step('purchase $productId');
}

/// 설정 뒤의 호출이 끝나지 않는 경계.
class _HangingApi extends _Api {
  @override
  Future<List<StoreProduct>> getProducts(List<String> ids) =>
      Completer<List<StoreProduct>>().future;

  @override
  Future<void> syncPurchases() => Completer<void>().future;

  @override
  Future<void> purchase(String productId) => Completer<void>().future;
}

const _product = StoreProduct(
  id: 'ad_free_1m',
  title: '광고 제거 1개월',
  priceLabel: '₩0',
);

void main() {
  late _Api api;

  RevenueCatPurchases purchases({
    String? apiKey = 'key',
    Set<String> productIds = const {'ad_free_1m'},
  }) => RevenueCatPurchases(apiKey: apiKey, productIds: productIds, api: api);

  setUp(() => api = _Api());

  group('revenueCatApiKey(D99 ②)', () {
    test('Test Store 키가 있으면(debug) 플랫폼과 상관없이 그 키', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          revenueCatApiKey(platform: platform, testStoreKey: 'test_x'),
          'test_x',
        );
      }
    });

    test('Test Store 키가 비면(release) Android goog, iOS appl, 그 밖은 null', () {
      expect(
        revenueCatApiKey(platform: TargetPlatform.android, testStoreKey: ''),
        startsWith('goog_'),
      );
      expect(
        revenueCatApiKey(platform: TargetPlatform.iOS, testStoreKey: ''),
        startsWith('appl_'),
      );
      expect(
        revenueCatApiKey(platform: TargetPlatform.macOS, testStoreKey: ''),
        isNull,
      );
    });

    test('debug 테스트 실행에서 Test Store 키 상수는 test_ 키입니다', () {
      expect(revenueCatTestStoreKey, startsWith('test_'));
    });
  });

  group('RevenueCatPurchases', () {
    test('처음 부를 때 한 번만 키로 설정합니다', () async {
      final adapter = purchases();
      await adapter.logIn('acc-1');
      await adapter.sync();
      expect(api.calls, ['configure key', 'logIn acc-1', 'sync']);
    });

    test('설정이 실패하면 OfflineError를 던지고 다음 호출에서 다시 설정합니다', () async {
      api.configureFailures = 1;
      final adapter = purchases();
      await expectLater(adapter.logIn('acc-1'), throwsA(isA<OfflineError>()));
      await adapter.logIn('acc-1');
      expect(api.calls, ['configure key', 'configure key', 'logIn acc-1']);
    });

    test('logIn 실패: 연결 문제는 OfflineError, 그 밖은 UnexpectedError', () async {
      final adapter = purchases();
      api.failWith = const RevenueCatFailure(
        RevenueCatFailureKind.offline,
        'net',
      );
      await expectLater(adapter.logIn('a'), throwsA(isA<OfflineError>()));
      api.failWith = const RevenueCatFailure(
        RevenueCatFailureKind.other,
        'boom',
      );
      await expectLater(
        adapter.logIn('a'),
        throwsA(isA<UnexpectedError>().having((e) => e.cause, 'cause', 'boom')),
      );
    });

    test('익명 사용자면 logOut을 부르지 않습니다(SDK가 던짐)', () async {
      api.anonymous = true;
      await purchases().logOut();
      expect(api.calls, ['configure key']);
    });

    test('연결된 사용자면 logOut', () async {
      await purchases().logOut();
      expect(api.calls, ['configure key', 'logOut']);
    });

    test('products는 광고 제거권 id로 조회하고, id가 없으면 SDK를 부르지 않습니다', () async {
      api.storeProducts = const [_product];
      expect(await purchases().products(), const [_product]);
      expect(api.calls.last, 'getProducts ad_free_1m');

      api.calls.clear();
      expect(await purchases(productIds: const {}).products(), isEmpty);
      expect(api.calls, isEmpty);
    });

    test('buy: 성공, 취소, 연결 실패, 그 밖의 실패', () async {
      final adapter = purchases();
      expect(await adapter.buy('ad_free_1m'), isA<PurchaseSucceeded>());
      expect(api.calls.last, 'purchase ad_free_1m');

      api.failWith = const RevenueCatFailure(
        RevenueCatFailureKind.cancelled,
        'c',
      );
      expect(await adapter.buy('ad_free_1m'), isA<PurchaseCancelled>());

      api.failWith = const RevenueCatFailure(
        RevenueCatFailureKind.offline,
        'n',
      );
      expect(
        await adapter.buy('ad_free_1m'),
        isA<PurchaseFailed>().having(
          (f) => f.error,
          'error',
          isA<OfflineError>(),
        ),
      );

      api.failWith = const RevenueCatFailure(RevenueCatFailureKind.other, 'x');
      expect(
        await adapter.buy('ad_free_1m'),
        isA<PurchaseFailed>().having(
          (f) => f.error,
          'error',
          isA<UnexpectedError>(),
        ),
      );
    });

    test('products와 sync는 시간 한계를 넘으면 TimeoutError, buy는 기다립니다', () async {
      final hanging = _HangingApi();
      final adapter = RevenueCatPurchases(
        apiKey: 'key',
        productIds: const {'ad_free_1m'},
        api: hanging,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(adapter.products(), throwsA(isA<TimeoutError>()));
      await expectLater(adapter.sync(), throwsA(isA<TimeoutError>()));
      var bought = false;
      unawaited(adapter.buy('ad_free_1m').then((_) => bought = true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bought, isFalse);
    });

    test('키가 없는 플랫폼이면 SDK를 부르지 않고 결제를 쓸 수 없습니다', () async {
      final adapter = purchases(apiKey: null);
      await adapter.logIn('a');
      await adapter.logOut();
      await adapter.sync();
      expect(await adapter.products(), isEmpty);
      expect(await adapter.buy('ad_free_1m'), isA<PurchaseFailed>());
      expect(api.calls, isEmpty);
    });
  });
}
