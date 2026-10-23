import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/interaction/single_open_guard.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/purchase/application/ad_free_controller.dart';
import 'package:myungli_diary/features/purchase/model/ad_free_date.dart';

/// IA `ad-free`의 출구 대상. 구매는 OS 결제 시트(`system-purchase`)가 맡습니다.
const Set<String> adFreeExits = {
  ScreenIds.systemPurchase,
  ScreenIds.legal,
  ScreenIds.purchaseHistory,
};

/// IA `ad-free`에서 이 화면이 처리하는 상태.
const Set<String> adFreeHandledStates = {'loading', 'error', 'offline'};

/// 광고 제거(`ad-free`, 결정 A75, D53·D88).
///
/// app-bar 아래 `offer-card` 하나입니다. 상품과 가격은 `Purchases.products()`에서 받는 동안
/// skeleton, 실패하면 error-state(다시 시도)이고, 오프라인이면 notice-banner `offline`과 함께
/// 구매 버튼만 꺼진 카드를 보입니다(가격은 받지 못해 가격 줄을 뺍니다). 오프라인은 연결이
/// 돌아와도 따로 감시하지 않고 화면에 다시 들어올 때 다시 받습니다.
///
/// * `Me.adFree`가 활성이면 카드가 `active`(사용 중 꼬리표와 만료일 "까지")입니다.
/// * 구매 버튼 → OS 결제 시트. 성공하면 [AdFreeController]가 햅틱·장부 맞추기·`Me` 갱신을 하고,
///   취소는 아무 일 없고, 실패는 오류 toast입니다. 구매 중에는 버튼이 처리 중 표시입니다.
/// * 구매 내역 버튼은 `purchase-history`, 약관 안내는 `legal`로 갑니다.
class AdFreeScreen extends ConsumerStatefulWidget {
  /// ad-free 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<AdFreeScreen> createState() => _AdFreeScreenState();
}

class _AdFreeScreenState extends ConsumerState<AdFreeScreen>
    with SingleOpenGuard<AdFreeScreen> {
  Future<void> _buy(StoreProduct product) async {
    final outcome = await ref
        .read(adFreeControllerProvider.notifier)
        .buy(product.id);
    if (outcome is PurchaseFailed && mounted) {
      showMyungliToast(
        context,
        errorMessage(AppLocalizations.of(context), outcome.error),
      );
    }
  }

  void _open(String screenId) =>
      guardOpen(() => context.push<void>(pathOf(screenId)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final purchasing = ref.watch(adFreeControllerProvider);
    final adFree = ref.watch(meProvider)?.adFree;
    final expiry = adFreeExpiryDate(
      l10n.localeName,
      adFree,
      ref.watch(profileTimezoneProvider),
    );
    final product = ref.watch(adFreeProductProvider);

    return Semantics(
      identifier: ScreenIds.adFree,
      child: Scaffold(
        key: const ValueKey(ScreenIds.adFree),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyungliAppBar.inner(
                title: l10n.adFreeBarTitle,
                titleIdentifier: SlotIds.adFreeBarTitle,
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                // 이용 중이면 상품을 받지 못해도 카드(이용 중 표시, 구매 내역 출구)를 보입니다.
                child: expiry != null
                    ? _content(l10n, product.value, expiry, purchasing)
                    : ScreenStateView<StoreProduct?>(
                        value: _offlineAsEmpty(product),
                        onRetry: () => ref.invalidate(adFreeProductProvider),
                        isStale: (product) => product == null,
                        data: (product) =>
                            _content(l10n, product, expiry, purchasing),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    AppLocalizations l10n,
    StoreProduct? product,
    String? expiry,
    bool purchasing,
  ) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        Space.s20,
        Space.s8,
        Space.s20,
        Space.s24 + bottom,
      ),
      children: [
        OfferCard(
          state: _cardState(
            product: product,
            active: expiry != null,
            purchasing: purchasing,
          ),
          head: l10n.adFreeOfferHead,
          // 가격은 스토어 문자열 그대로, 기간·자동 갱신 아님은 가격과 상관없이 늘 보입니다.
          price: product?.priceLabel,
          period: l10n.adFreeOfferPeriod,
          buyLabel: l10n.adFreeBuyCta,
          historyLabel: l10n.adFreeHistoryCta,
          legalNotice: l10n.adFreeLegalNotice,
          statusLabel: l10n.purchaseStatusActive,
          remaining: expiry == null ? null : l10n.adFreeStatusRemaining(expiry),
          onBuy: product == null ? null : () => _buy(product),
          onHistory: () => _open(ScreenIds.purchaseHistory),
          onLegal: () => _open(ScreenIds.legal),
        ),
      ],
    );
  }

  /// 오프라인 오류를 값 없는 데이터(null)로 바꿔 notice-banner와 꺼진 구매 버튼으로 보입니다.
  AsyncValue<StoreProduct?> _offlineAsEmpty(AsyncValue<StoreProduct> product) =>
      product.hasError && product.error is OfflineError
      ? const AsyncData<StoreProduct?>(null)
      : product;

  OfferCardState _cardState({
    required StoreProduct? product,
    required bool active,
    required bool purchasing,
  }) {
    if (active) {
      return OfferCardState.active;
    }
    if (product == null) {
      return OfferCardState.offline;
    }
    return purchasing ? OfferCardState.purchasing : OfferCardState.available;
  }
}
