import 'dart:async';

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
import 'package:myungli_diary/features/purchase/presentation/ad_free_screen.dart';

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
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    overrides: [purchasesProvider.overrideWithValue(purchases)],
  );
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.adFree)),
  );
  await pumpUntilScreen(tester, ScreenIds.adFree);
  await settleWithIo(tester);
  return container;
}

PrimaryButton _buy(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byKey(OfferCard.buyKey));

void main() {
  test('처리하는 상태와 출구가 IA와 같다', () {
    expect(adFreeHandledStates, {'loading', 'error', 'offline'});
    expect(adFreeExits, {
      ScreenIds.systemPurchase,
      ScreenIds.legal,
      ScreenIds.purchaseHistory,
    });
  });

  testWidgets('loading 뒤 상품 가격 문장이 보인다', (tester) async {
    await _open(tester, FakePurchases());
    await expectAppBarTitle(tester, SlotIds.adFreeBarTitle, _ko.adFreeBarTitle);
    expect(find.text(_ko.adFreeOfferPrice('가격')), findsOneWidget);
    expect(find.text(_ko.adFreeOfferHead), findsOneWidget);
    expect(_buy(tester).label, _ko.adFreeBuyCta);
    expect(_buy(tester).onPressed, isNotNull);
    expect(find.text(_ko.adFreeHistoryCta), findsOneWidget);
  });

  testWidgets('상품 실패면 error와 다시 시도', (tester) async {
    final purchases = _ProductsFailing(UnexpectedError(StateError('x')));
    await _open(tester, purchases);
    expect(find.byKey(OfferCard.cardKey), findsNothing);
    expect(find.text(_ko.actionRetry), findsOneWidget);

    await tester.tap(find.text(_ko.actionRetry));
    await settleWithIo(tester);
    expect(purchases.productsCalls, 2);
  });

  testWidgets('오프라인이면 offline 안내와 비활성 구매 버튼', (tester) async {
    await _open(tester, _ProductsFailing(const OfflineError()));
    expect(find.byType(NoticeBanner), findsOneWidget);
    expect(find.text(_ko.noticeOffline), findsOneWidget);
    expect(_buy(tester).onPressed, isNull);
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
