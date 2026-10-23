import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart'
    show SingleChildScrollView, TextDirection, ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/purchase.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_period.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_status.dart';
import 'package:myungli_diary/core/clock/clock.dart'
    show profileTimezoneProvider;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/purchase/presentation/purchase_history_screen.dart';

import '../../support/app_bar_title.dart';
import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';
import '../../support/purchase_network.dart';
import '../../support/purchase_stubs.dart';

final _ko = AppLocalizationsKo();

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
    await untilLoaded(tester);
  }
  await settleWithIo(tester, allowOngoing: allowOngoing);
  return container;
}

/// 구매일과 (있으면) 사용 기간으로 meta 한 줄을 ARB 조각으로 조립합니다.
String _meta(String purchased, {String? start, String? end}) {
  final head = _ko.purchaseMetaPurchased(purchased);
  if (start == null || end == null) {
    return head;
  }
  final period = _ko.purchaseMetaPeriod(start, end);
  return '$head${_ko.purchaseMetaSeparator}$period';
}

Map<String, Object?> _item(
  String productId,
  String purchasedAt,
  String status, {
  String? startsAt,
  String? endsAt,
}) => {
  'productId': productId,
  'purchasedAt': purchasedAt,
  'status': status,
  if (startsAt != null) 'period': {'startsAt': startsAt, 'endsAt': endsAt},
};

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
        _meta('2026. 10. 13.', start: '2026. 10. 13.', end: '2026. 11. 12.'),
      );
    });

    test('기간이 없으면 구매일만', () {
      expect(meta(DateTime.utc(2026, 10, 13, 3)), _meta('2026. 10. 13.'));
    });

    test('날짜는 기기 시간대 기준이다', () {
      expect(meta(DateTime.utc(2026, 10, 12, 15, 30)), _meta('2026. 10. 13.'));
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
      find.text(
        _meta('2026. 10. 12.', start: '2026. 10. 12.', end: '2026. 11. 12.'),
      ),
      findsOneWidget,
    );
    expect(find.text(_meta('2026. 7. 1.')), findsOneWidget);
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
    // empty-state 바로 아래 space.16에 놓입니다.
    expect(
      tester.getTopLeft(_notice).dy -
          tester.getBottomLeft(find.byType(EmptyState)).dy,
      closeTo(Space.s16, 0.01),
    );
  });

  testWidgets('loading에서는 skeleton과 missing.notice 없음, 받으면 보인다', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _open(
      tester,
      purchases: GatedPurchases(syncGate: gate),
      allowOngoing: true,
    );
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(_notice, findsNothing);
    gate.complete();
    await untilLoaded(tester);
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
    await untilLoaded(tester);

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

  testWidgets('pending·expired(기간 없음)·합친 구매를 받은 그대로 server 순서로 보인다', (
    tester,
  ) async {
    // 세 번째는 합친 구매라 구매일이 사용 기간 시작보다 이릅니다(spec §10).
    final pending = _meta(
      '2026. 10. 12.',
      start: '2026. 10. 13.',
      end: '2026. 11. 13.',
    );
    final expired = _meta('2026. 9. 1.');
    final merged = _meta(
      '2026. 10. 1.',
      start: '2026. 10. 5.',
      end: '2026. 11. 5.',
    );
    await _open(
      tester,
      network: _listReplaced([
        _item(
          'ad_free_1month',
          '2026-10-12T03:00:00Z',
          'pending',
          startsAt: '2026-10-13T03:00:00Z',
          endsAt: '2026-11-13T03:00:00Z',
        ),
        _item('ad_free_1month', '2026-09-01T03:00:00Z', 'expired'),
        _item(
          'ad_free_1month',
          '2026-10-01T03:00:00Z',
          'active',
          startsAt: '2026-10-05T03:00:00Z',
          endsAt: '2026-11-05T03:00:00Z',
        ),
      ]),
    );
    expect(find.text(_ko.purchaseStatusPending), findsOneWidget);
    expect(find.text(_ko.purchaseStatusExpired), findsOneWidget);
    final tops = [
      for (final meta in [pending, expired, merged])
        tester.getTopLeft(find.text(meta)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('날짜는 프로필 시간대가 아니라 기기 시간대 기준이다', (tester) async {
    // 기기(시나리오) 시간대는 Asia/Seoul, 프로필 시간대는 뉴욕으로 어긋나게 둡니다.
    // 2026-10-12T15:30Z는 서울에서 13일, 뉴욕에서 12일입니다.
    final container = await pumpApp(
      tester,
      scenario: 'ad-free-active',
      overrides: [
        cachedProfileProvider.overrideWith(
          (ref) async => Profile.fromJson({
            'honorific': '하늘',
            'language': 'ko',
            'currentTimezone': 'America/New_York',
            'birth': {
              'calendar': 'solar',
              'date': {'year': 1990, 'month': 5, 'day': 15},
              'isLeapMonth': false,
              'time': {'status': 'unknown'},
              'gender': 'female',
              'timezone': 'Asia/Seoul',
              'place': {'status': 'not_asked'},
            },
            'notification': {'status': 'not_asked'},
          }),
        ),
      ],
      network: _listReplaced([
        _item('ad_free_1month', '2026-10-12T15:30:00Z', 'owned'),
      ]),
    );
    unawaited(
      container
          .read(routerProvider)
          .push<void>(pathOf(ScreenIds.purchaseHistory)),
    );
    await pumpUntilScreen(tester, ScreenIds.purchaseHistory);
    await untilLoaded(tester);
    expect(container.read(profileTimezoneProvider), 'America/New_York');
    expect(find.text(_meta('2026. 10. 13.')), findsOneWidget);
  });

  testWidgets('스토어 이름이 필요한 줄은 상품 목록이 올 때까지 loading, 이름은 title', (tester) async {
    final gate = Completer<void>();
    await _open(
      tester,
      purchases: GatedPurchases(
        productsGate: gate,
        catalog: const [
          StoreProduct(id: 'store_x', title: '스토어 이름', priceLabel: '가격'),
        ],
      ),
      network: _listReplaced([
        _item('store_x', '2026-10-12T03:00:00Z', 'owned'),
      ]),
      allowOngoing: true,
    );
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(find.text('store_x'), findsNothing);

    gate.complete();
    await untilLoaded(tester);
    expect(find.text('스토어 이름'), findsOneWidget);
    expect(find.text('store_x'), findsNothing);
  });

  testWidgets('광고 제거권 줄만 있으면 스토어 상품 목록을 받지 않는다', (tester) async {
    final purchases = GatedPurchases();
    await _open(
      tester,
      purchases: purchases,
      network: _listReplaced([
        _item('ad_free_1month', '2026-10-12T03:00:00Z', 'owned'),
        _item('ad_free_1month', '2026-07-01T03:00:00Z', 'owned'),
      ]),
    );
    expect(find.byKey(PurchaseRowGroup.rowKey), findsNWidgets(2));
    expect(purchases.productsCalls, 0);
  });

  testWidgets('목록 아래 missing.notice도 space.16 간격이다', (tester) async {
    await _open(tester);
    expect(
      tester.getTopLeft(_notice).dy -
          tester.getBottomLeft(find.byType(PurchaseRowGroup)).dy,
      closeTo(Space.s16, 0.01),
    );
  });

  testWidgets('빈 목록도 아래 여백에 하단 safe area를 더한다', (tester) async {
    tester.view.viewPadding = FakeViewPadding(
      bottom: 34 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewPadding);
    await _open(tester, scenario: 'member');
    final scroll = tester.widget<SingleChildScrollView>(
      find.ancestor(
        of: find.byType(EmptyState),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final padding = scroll.padding!.resolve(TextDirection.ltr);
    expect(padding.bottom, closeTo(Space.s24 + 34, 0.01));
    expect(padding.left, Space.s20);
    expect(padding.right, Space.s20);
  });
}
