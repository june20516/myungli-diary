import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/purchase.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_period.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_status.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/features/purchase/presentation/purchase_history_screen.dart';

import '../../support/app_bar_title.dart';
import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';
import '../../support/purchase_network.dart';

final _ko = AppLocalizationsKo();

/// `sync`를 [gate]가 열릴 때까지 붙잡고 호출 수를 세는 구매 대역.
final class _GatedSync implements Purchases {
  new(this.gate);

  final Completer<void> gate;
  int syncCalls = 0;

  @override
  Future<void> logIn(String accountId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<void> sync() async {
    syncCalls++;
    await gate.future;
  }

  @override
  Future<List<StoreProduct>> products() async => const [];

  @override
  Future<PurchaseOutcome> buy(String productId) async =>
      const PurchaseCancelled();
}

/// `listPurchases` 응답을 [items]로 바꿉니다.
Interceptor _listReplaced(List<Map<String, Object?>> items) =>
    InterceptorsWrapper(
      onResponse: (response, handler) {
        if (response.requestOptions.path == '/v1/me/purchases') {
          (response.data! as Map<String, Object?>)['items'] = items;
        }
        handler.next(response);
      },
    );

Future<ProviderContainer> _open(
  WidgetTester tester, {
  String scenario = 'ad-free-active',
  Purchases? purchases,
  Interceptor? network,
  bool allowOngoing = false,
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    overrides: [
      if (purchases != null) purchasesProvider.overrideWithValue(purchases),
    ],
    network: network,
  );
  unawaited(
    container
        .read(routerProvider)
        .push<void>(pathOf(ScreenIds.purchaseHistory)),
  );
  await pumpUntilScreen(tester, ScreenIds.purchaseHistory);
  if (!allowOngoing) {
    await _untilLoaded(tester);
  }
  await settleWithIo(tester, allowOngoing: allowOngoing);
  return container;
}

/// 불러오기(sync, 장부 맞추기, 목록)가 끝나 skeleton이 사라질 때까지 기다립니다.
Future<void> _untilLoaded(WidgetTester tester) => pumpUntil(
  tester,
  () => find.byKey(const ValueKey('screen-state.loading')).evaluate().isEmpty,
);

Finder get _notice => find.text(_ko.purchaseHistoryMissingNotice);

void main() {
  group('purchaseMeta', () {
    setUpAll(() => initializeDateFormatting('ko'));

    final period = PurchasePeriod(
      startsAt: DateTime.utc(2026, 10, 13, 3),
      endsAt: DateTime.utc(2026, 11, 12, 3),
    );

    String meta(DateTime purchasedAt, [PurchasePeriod? period]) => purchaseMeta(
      _ko,
      Purchase(
        productId: 'p',
        purchasedAt: purchasedAt,
        status: PurchaseStatus.active,
        period: period,
      ),
      locale: 'ko',
      timezone: 'Asia/Seoul',
    );

    test('구매일, 구분자, 기간을 잇는다', () {
      expect(
        meta(DateTime.utc(2026, 10, 13, 3), period),
        '2026. 10. 13. 구매 · 2026. 10. 13.~2026. 11. 12.',
      );
    });

    test('기간이 없으면 구매일만', () {
      expect(meta(DateTime.utc(2026, 10, 13, 3)), '2026. 10. 13. 구매');
    });

    test('날짜는 기기 시간대 기준이다', () {
      expect(meta(DateTime.utc(2026, 10, 12, 15, 30)), '2026. 10. 13. 구매');
    });
  });

  testWidgets('목록이면 줄과 missing.notice', (tester) async {
    await _open(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.purchaseHistoryBarTitle,
      _ko.purchaseHistoryBarTitle,
    );
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(4));
    expect(find.text(_ko.purchaseProductAdFreeMonth), findsNWidgets(4));
    expect(find.text(_ko.purchaseStatusActive), findsOneWidget);
    expect(find.text(_ko.purchaseStatusRefunded), findsOneWidget);
    expect(find.text(_ko.purchaseStatusExpired), findsNWidgets(2));
    expect(
      find.text('2026. 10. 12. 구매 · 2026. 10. 12.~2026. 11. 12.'),
      findsOneWidget,
    );
    expect(find.text('2026. 7. 1. 구매'), findsOneWidget);
    expect(_notice, findsOneWidget);
  });

  testWidgets('빈 목록이면 empty-state(receipt)와 그 아래 missing.notice', (
    tester,
  ) async {
    await _open(tester, scenario: 'member');
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(_ko.purchaseHistoryEmptyBody), findsOneWidget);
    expect(_notice, findsOneWidget);
    expect(
      tester.getTopLeft(_notice).dy,
      greaterThan(tester.getBottomLeft(find.byType(EmptyState)).dy),
    );
  });

  testWidgets('loading에서는 skeleton과 missing.notice 없음, 받으면 보인다', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _open(tester, purchases: _GatedSync(gate), allowOngoing: true);
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(_notice, findsNothing);
    gate.complete();
    await _untilLoaded(tester);
    expect(_notice, findsOneWidget);
  });

  testWidgets('error면 다시 시도와 notice 없음', (tester) async {
    await _open(tester, network: listPurchasesFailing(1, serverFailure));
    expect(find.text(_ko.actionRetry), findsOneWidget);
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNothing);
    expect(_notice, findsNothing);
  });

  testWidgets('offline이면 오프라인 안내와 notice 없음', (tester) async {
    await _open(tester, network: listPurchasesFailing(1, offlineFailure));
    expect(find.text(_ko.errorOffline), findsOneWidget);
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNothing);
    expect(_notice, findsNothing);
  });

  testWidgets('error 다시 시도는 sync부터', (tester) async {
    final purchases = FakePurchases();
    await _open(
      tester,
      purchases: purchases,
      network: listPurchasesFailing(1, serverFailure),
    );
    expect(purchases.syncCalls, 1);

    await tester.tap(find.text(_ko.actionRetry));
    await _untilLoaded(tester);

    expect(purchases.syncCalls, 2);
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(4));
    expect(_notice, findsOneWidget);
  });

  testWidgets('owned·모르는 상태 줄은 상태 자리가 비어 있다', (tester) async {
    await _open(
      tester,
      network: _listReplaced([
        {
          'productId': 'ad_free_1month',
          'purchasedAt': '2026-10-12T03:00:00Z',
          'status': 'owned',
        },
        {
          'productId': 'other_product',
          'purchasedAt': '2026-10-11T03:00:00Z',
          'status': 'brand_new_status',
        },
      ]),
    );
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(2));
    expect(find.byKey(PurchaseRowGroup.statusKey), findsNothing);
    // 스토어에도 광고 제거권 목록에도 없는 상품은 상품 id 그대로입니다.
    expect(find.text('other_product'), findsOneWidget);
  });
}
