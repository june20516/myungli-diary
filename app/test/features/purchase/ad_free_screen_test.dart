import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../../support/app_bar_title.dart';
import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

/// 상품을 받는 데 실패하는 구매 대역.
final class _ProductsFailing implements Purchases {
  new(this.error);

  final AppError error;
  int productsCalls = 0;

  @override
  Future<void> logIn(String accountId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<void> sync() async {}

  @override
  Future<List<StoreProduct>> products() async {
    productsCalls++;
    throw error;
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async =>
      const PurchaseCancelled();
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  Purchases purchases, {
  String scenario = 'member',
  bool allowOngoing = false,
  Interceptor? network,
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    overrides: [purchasesProvider.overrideWithValue(purchases)],
    network: network,
  );
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.adFree)),
  );
  await pumpUntilScreen(tester, ScreenIds.adFree);
  await settleWithIo(tester, allowOngoing: allowOngoing);
  return container;
}

/// 상품 받기를 [gate]가 열릴 때까지 붙잡는 구매 대역.
final class _GatedProducts implements Purchases {
  new(this.gate);

  final Completer<void> gate;
  final inner = FakePurchases();

  @override
  Future<void> logIn(String accountId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<void> sync() async {}

  @override
  Future<List<StoreProduct>> products() async {
    await gate.future;
    return await inner.products();
  }

  @override
  Future<PurchaseOutcome> buy(String productId) => inner.buy(productId);
}

/// `restorePurchases`가 불린 뒤의 `getMe` 응답을 광고 제거 활성으로 바꿉니다.
Interceptor _activeAfterRestore() {
  var restored = false;
  return InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/v1/billing/restore') {
        restored = true;
      }
      handler.next(options);
    },
    onResponse: (response, handler) {
      if (restored && response.requestOptions.path == '/v1/me') {
        (response.data! as Map<String, Object?>)['adFree'] = {
          'active': true,
          'expiresAt': '2026-11-12T03:00:00Z',
        };
      }
      handler.next(response);
    },
  );
}

PrimaryButton _buy(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byKey(OfferCard.buyKey));

void main() {
  testWidgets('loading 중에는 skeleton, 받은 뒤 스토어 가격과 기간 줄이 보인다', (tester) async {
    covers(const Covers(states: ['ad-free:loading']));
    final gate = Completer<void>();
    await _open(tester, _GatedProducts(gate), allowOngoing: true);
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(find.byKey(OfferCard.cardKey), findsNothing);

    gate.complete();
    await settleWithIo(tester);
    await expectAppBarTitle(tester, SlotIds.adFreeBarTitle, _ko.adFreeBarTitle);
    expect(find.byKey(const ValueKey('screen-state.loading')), findsNothing);
    expect(find.text('가격'), findsOneWidget);
    expect(find.text(_ko.adFreeOfferPeriod), findsOneWidget);
    expect(find.text(_ko.adFreeOfferHead), findsOneWidget);
    expect(_buy(tester).label, _ko.adFreeBuyCta);
    expect(_buy(tester).onPressed, isNotNull);
    expect(find.text(_ko.adFreeHistoryCta), findsOneWidget);
  });

  testWidgets('상품 실패면 error와 다시 시도', (tester) async {
    covers(const Covers(states: ['ad-free:error']));
    final purchases = _ProductsFailing(UnexpectedError(StateError('x')));
    await _open(tester, purchases);
    expect(find.byKey(OfferCard.cardKey), findsNothing);
    expect(find.text(_ko.actionRetry), findsOneWidget);

    await tester.tap(find.text(_ko.actionRetry));
    await settleWithIo(tester);
    expect(purchases.productsCalls, 2);
  });

  testWidgets('오프라인이면 offline 안내와 비활성 구매 버튼, 가격 줄 없음', (tester) async {
    covers(const Covers(states: ['ad-free:offline']));
    await _open(tester, _ProductsFailing(const OfflineError()));
    expect(find.byType(NoticeBanner), findsOneWidget);
    expect(find.text(_ko.noticeOffline), findsOneWidget);
    expect(_buy(tester).onPressed, isNull);
    expect(find.text('가격'), findsNothing);
    expect(find.text(_ko.adFreeOfferPeriod), findsOneWidget);
    expect(find.text(_ko.adFreeOfferHead), findsOneWidget);
    final history = tester.widget<PrimaryButton>(
      find.byKey(OfferCard.historyKey),
    );
    expect(history.onPressed, isNotNull);
  });

  testWidgets('이용 중이면 상품을 못 받아도 카드는 active다', (tester) async {
    await _open(
      tester,
      _ProductsFailing(UnexpectedError(StateError('x'))),
      scenario: 'ad-free-active',
    );
    expect(find.byKey(OfferCard.cardKey), findsOneWidget);
    expect(find.text(_ko.purchaseStatusActive), findsOneWidget);
    expect(find.byKey(OfferCard.buyKey), findsNothing);
    expect(find.text(_ko.actionRetry), findsNothing);
    expect(
      tester.widget<PrimaryButton>(find.byKey(OfferCard.historyKey)).onPressed,
      isNotNull,
    );
  });

  testWidgets('구매 성공이면 getMe를 다시 받아 active로 바뀐다', (tester) async {
    final purchases = FakePurchases();
    await _open(tester, purchases, network: _activeAfterRestore());
    expect(find.byKey(OfferCard.buyKey), findsOneWidget);

    await tester.tap(find.byKey(OfferCard.buyKey));
    await settleWithIo(tester);

    expect(purchases.buyCalls, 1);
    expect(find.byKey(OfferCard.buyKey), findsNothing);
    expect(find.text(_ko.purchaseStatusActive), findsOneWidget);
  });

  testWidgets('Me.adFree 활성이면 사용 중 꼬리표와 남은 기간', (tester) async {
    await _open(tester, FakePurchases(), scenario: 'ad-free-active');
    expect(find.text(_ko.purchaseStatusActive), findsOneWidget);
    expect(
      find.text(
        _ko.adFreeStatusRemaining(
          DateFormat.yMMMd('ko').format(DateTime(2026, 11, 12)),
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(OfferCard.buyKey), findsNothing);
  });

  testWidgets('구매 실패면 오류 toast', (tester) async {
    final purchases = FakePurchases(
      outcomes: const [PurchaseFailed(OfflineError())],
    );
    await _open(tester, purchases);
    await tester.tap(find.byKey(OfferCard.buyKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(purchases.buyCalls, 1);
    expect(find.text(_ko.errorOffline), findsOneWidget);
    expect(_buy(tester).onPressed, isNotNull);
    // toast가 스스로 사라질 때까지 기다립니다.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('구매 내역 버튼은 purchase-history로, 약관 안내는 legal로 간다', (tester) async {
    final container = await _open(tester, FakePurchases());
    await tester.tap(find.byKey(OfferCard.historyKey));
    await pumpUntilScreen(tester, ScreenIds.purchaseHistory);

    container.read(routerProvider).pop();
    await settleWithIo(tester);
    await tester.tap(find.byKey(OfferCard.legalKey));
    await pumpUntilScreen(tester, ScreenIds.legal);
  });
}
