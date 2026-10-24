import 'dart:async';

import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/purchases.dart';

import 'onboarding_steps.dart';

/// `sync`·`products`를 게이트로 붙잡거나 실패시키는 구매 대역(나머지는 [FakePurchases]).
///
/// [syncGate]가 있으면 그 Completer가 끝날 때까지 `sync`가 멈추고, [productsGate]가 있으면
/// `products`가 멈춥니다. [productsError]가 있으면 `products`가 그 오류를 던집니다.
final class GatedPurchases implements Purchases {
  /// 대역을 만듭니다.
  new({
    this.syncGate,
    this.productsGate,
    this.productsError,
    List<StoreProduct>? catalog,
  }) : inner = catalog == null
           ? FakePurchases()
           : FakePurchases(catalog: catalog);

  /// 열릴 때까지 `sync`를 붙잡는 게이트. 첫 불러오기 뒤에 걸어 다시 시도만 붙잡을 수 있습니다.
  Completer<void>? syncGate;

  /// 열릴 때까지 `products`를 붙잡는 게이트.
  final Completer<void>? productsGate;

  /// `products`가 던질 오류.
  final AppError? productsError;

  /// 나머지 동작을 맡는 기본 대역.
  final FakePurchases inner;

  /// `sync` 호출 수.
  int syncCalls = 0;

  /// `products` 호출 수.
  int productsCalls = 0;

  @override
  Future<void> logIn(String accountId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<void> sync() async {
    syncCalls++;
    await syncGate?.future;
  }

  @override
  Future<List<StoreProduct>> products() async {
    productsCalls++;
    await productsGate?.future;
    final failure = productsError;
    if (failure != null) {
      throw failure;
    }
    return await inner.products();
  }

  @override
  Future<PurchaseOutcome> buy(String productId) => inner.buy(productId);
}

/// 화면의 skeleton(`screen-state.loading`)이 사라질 때까지 기다립니다.
Future<void> untilLoaded(WidgetTester tester) => pumpUntil(
  tester,
  () => find.byKey(const ValueKey('screen-state.loading')).evaluate().isEmpty,
);
