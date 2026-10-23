import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';
import '../support/purchase_network.dart';
import '../support/purchase_stubs.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// 앱을 띄우고 설정 → 광고 제거 줄을 눌러 `ad-free`로 갑니다.
Future<ProviderContainer> _openAdFree(
  WidgetTester tester, {
  String scenario = 'member',
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
    container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
  );
  await pumpUntilScreen(tester, ScreenIds.settings);
  await settleWithIo(tester);
  await tester.ensureVisible(find.byKey(SettingsScreen.adFreeRowKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(SettingsScreen.adFreeRowKey));
  await pumpUntilScreen(tester, ScreenIds.adFree);
  await settleWithIo(tester, allowOngoing: allowOngoing);
  return container;
}

/// `ad-free`에서 구매 내역 버튼을 눌러 `purchase-history`로 가고, 불러오기가 끝나길 기다립니다.
Future<void> _openHistory(
  WidgetTester tester, {
  bool allowOngoing = false,
}) async {
  await tester.tap(find.byKey(OfferCard.historyKey));
  await pumpUntilScreen(tester, ScreenIds.purchaseHistory);
  if (!allowOngoing) {
    await untilLoaded(tester);
  }
  await settleWithIo(tester, allowOngoing: allowOngoing);
}

void main() {
  testWidgets('설정 → 광고 제거(사용 중) → 구매 내역에 네 줄', (tester) async {
    covers(
      const Covers(exits: ['settings>ad-free', 'ad-free>purchase-history']),
    );
    await _openAdFree(tester, scenario: 'ad-free-active');
    expect(find.text(_ko.purchaseStatusActive), findsOneWidget);
    expect(find.byKey(OfferCard.buyKey), findsNothing);

    await _openHistory(tester);

    expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(4));
    expect(find.text(_ko.purchaseHistoryMissingNotice), findsOneWidget);
  });

  testWidgets('구매 내역이 비면 empty와 missing.notice', (tester) async {
    covers(const Covers(states: ['purchase-history:empty']));
    await _openAdFree(tester);
    await _openHistory(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(_ko.purchaseHistoryEmptyBody), findsOneWidget);
    expect(find.text(_ko.purchaseHistoryMissingNotice), findsOneWidget);
  });

  testWidgets('구매 내역 loading은 skeleton, 끝나면 목록', (tester) async {
    covers(const Covers(states: ['purchase-history:loading']));
    final gate = Completer<void>();
    final purchases = GatedPurchases(syncGate: gate);
    await _openAdFree(tester, scenario: 'ad-free-active', purchases: purchases);
    await _openHistory(tester, allowOngoing: true);
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(find.text(_ko.purchaseHistoryMissingNotice), findsNothing);

    gate.complete();
    await untilLoaded(tester);
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(4));
  });

  testWidgets('구매 내역 error는 다시 시도로 회복', (tester) async {
    covers(const Covers(states: ['purchase-history:error']));
    await _openAdFree(
      tester,
      scenario: 'ad-free-active',
      network: listPurchasesFailing(1, serverFailure),
    );
    await _openHistory(tester);
    expect(find.text(_ko.actionRetry), findsOneWidget);
    expect(find.text(_ko.purchaseHistoryMissingNotice), findsNothing);

    await tester.tap(find.text(_ko.actionRetry));
    await untilLoaded(tester);
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(4));
  });

  testWidgets('구매 내역 offline은 오프라인 안내', (tester) async {
    covers(const Covers(states: ['purchase-history:offline']));
    await _openAdFree(
      tester,
      scenario: 'ad-free-active',
      network: listPurchasesFailing(1, offlineFailure),
    );
    await _openHistory(tester);
    expect(find.text(_ko.errorOffline), findsOneWidget);
    expect(find.text(_ko.purchaseHistoryMissingNotice), findsNothing);
  });

  testWidgets('광고 제거 loading은 skeleton, 상품을 받으면 카드', (tester) async {
    covers(const Covers(states: ['ad-free:loading']));
    final gate = Completer<void>();
    await _openAdFree(
      tester,
      purchases: GatedPurchases(productsGate: gate),
      allowOngoing: true,
    );
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(find.byKey(OfferCard.cardKey), findsNothing);

    gate.complete();
    await untilLoaded(tester);
    expect(find.byKey(OfferCard.cardKey), findsOneWidget);
  });

  testWidgets('광고 제거 error는 다시 시도', (tester) async {
    covers(const Covers(states: ['ad-free:error']));
    await _openAdFree(
      tester,
      purchases: GatedPurchases(
        productsError: UnexpectedError(StateError('x')),
      ),
    );
    expect(find.byKey(OfferCard.cardKey), findsNothing);
    expect(find.text(_ko.actionRetry), findsOneWidget);
  });

  testWidgets('광고 제거 offline은 안내와 꺼진 구매 버튼', (tester) async {
    covers(const Covers(states: ['ad-free:offline']));
    await _openAdFree(
      tester,
      purchases: GatedPurchases(productsError: const OfflineError()),
    );
    expect(find.byType(NoticeBanner), findsOneWidget);
    expect(find.text(_ko.noticeOffline), findsOneWidget);
  });

  testWidgets('광고 제거 구매 성공 뒤 설정 줄이 남은 기간으로 바뀐다', (tester) async {
    covers(const Covers(decisions: ['D53']));
    final purchases = FakePurchases();
    final container = await _openAdFree(
      tester,
      purchases: purchases,
      network: activeAfterRestore(),
    );
    final meCalls = _fake(container).callCountOf('getMe');
    expect(_fake(container).callCountOf('restorePurchases'), 0);

    await tester.tap(find.byKey(OfferCard.buyKey));
    await settleWithIo(tester);

    expect(purchases.buyCalls, 1);
    expect(_fake(container).callCountOf('restorePurchases'), 1);
    expect(_fake(container).callCountOf('getMe'), meCalls + 1);

    container.read(routerProvider).pop();
    await settleWithIo(tester);
    await tester.ensureVisible(find.byKey(SettingsScreen.adFreeRowKey));
    await tester.pumpAndSettle();
    final row = tester.widget<SettingsRow>(
      find.byKey(SettingsScreen.adFreeRowKey),
    );
    expect(
      row.value,
      _ko.settingsAdFreeLabelActive(
        DateFormat.yMMMd('ko').format(DateTime(2026, 11, 12)),
      ),
    );
  });
}
