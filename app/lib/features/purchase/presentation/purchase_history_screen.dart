import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/purchase.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_status.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/purchase/application/purchase_history_controller.dart';
import 'package:myungli_diary/features/purchase/application/purchase_providers.dart';
import 'package:myungli_diary/features/purchase/model/purchase_labels.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// IA `purchase-history`에서 이 화면이 처리하는 상태. 출구는 없습니다.
const Set<String> purchaseHistoryHandledStates = {
  'loading',
  'empty',
  'error',
  'offline',
};

/// `purchase-row`의 구매일 줄과 사용 기간 줄입니다. 기간이 없으면 `period`가 null입니다.
typedef PurchaseMeta = ({String purchased, String? period});

/// 구매 한 건의 `purchase-row` meta: 구매일과 사용 기간을 따로 만듭니다(구분 글자로 잇지 않음, W44).
///
/// 날짜는 [timezone]의 달력 날짜를 [locale]의 짧은 날짜로 보입니다.
PurchaseMeta purchaseMeta(
  AppLocalizations l10n,
  Purchase purchase, {
  required String locale,
  required String timezone,
}) {
  String date(DateTime instant) {
    final local = localTimeIn(instant, timezone);
    return DateFormat.yMd(locale)
        .format(DateTime(local.year, local.month, local.day));
  }

  final period = purchase.period;
  return (
    purchased: l10n.purchaseMetaPurchased(date(purchase.purchasedAt)),
    period: period == null
        ? null
        : l10n.purchaseMetaPeriod(date(period.startsAt), date(period.endsAt)),
  );
}

/// 구매 내역(`purchase-history`, 결정 A76, D88).
///
/// 들어올 때마다 [PurchaseHistoryController]가 sync, 장부 맞추기, 목록 받기를 차례로 합니다.
/// 목록이 있으면 `purchase-row` 묶음 카드, 비면 `empty-state`이고, 어느 쪽이든 아래에
/// `missing.notice`가 있습니다. `loading`·`error`·`offline`에서는 없습니다.
/// 다시 시도는 sync부터 다시 합니다. 출구는 없습니다.
class PurchaseHistoryScreen extends ConsumerWidget {
  /// 구매 내역 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(purchaseHistoryProvider);
    return Semantics(
      identifier: ScreenIds.purchaseHistory,
      child: Scaffold(
        key: const ValueKey(ScreenIds.purchaseHistory),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyungliAppBar.inner(
                title: l10n.purchaseHistoryBarTitle,
                titleIdentifier: SlotIds.purchaseHistoryBarTitle,
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ScreenStateView<List<Purchase>>(
                  value: _awaitingStoreNames(ref, history),
                  onRetry: () =>
                      ref.read(purchaseHistoryProvider.notifier).retry(),
                  skeleton: const Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.s20,
                      Space.s12,
                      Space.s20,
                      0,
                    ),
                    child: PurchaseRowGroup.loading(),
                  ),
                  isEmpty: (purchases) => purchases.isEmpty,
                  empty: _EmptyWithNotice(body: l10n.purchaseHistoryEmptyBody),
                  data: (purchases) => _PurchaseList(purchases: purchases),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상품 이름을 스토어에서 받아야 하는 줄(광고 제거권이 아닌 상품)이 있는지.
bool _needsStoreNames(WidgetRef ref, List<Purchase> purchases) {
  final adFreeProductIds = ref.watch(adFreeProductIdsProvider);
  return purchases.any(
    (purchase) => !adFreeProductIds.contains(purchase.productId),
  );
}

/// 상품 이름을 스토어에서 받아야 하는 줄이 있으면 그 목록이 올 때까지 loading으로 둡니다.
///
/// 이름이 상품 id에서 스토어 title로 깜빡 바뀌지 않게 첫 그리기 전에 함께 기다립니다.
/// 광고 제거권 줄만 있으면(스토어 이름이 필요 없으면) 상품 목록을 받지 않습니다.
AsyncValue<List<Purchase>> _awaitingStoreNames(
  WidgetRef ref,
  AsyncValue<List<Purchase>> history,
) {
  final purchases = history.value;
  if (purchases == null) {
    return history;
  }
  if (_needsStoreNames(ref, purchases) &&
      ref.watch(storeProductsProvider).isLoading) {
    return const AsyncLoading<List<Purchase>>();
  }
  return history;
}

/// 목록의 바깥 여백. 좌우 `space.20`, 아래는 하단 safe area까지 둡니다. 빈 목록은 세로만 씁니다.
EdgeInsets _contentPadding(BuildContext context) => EdgeInsets.fromLTRB(
  Space.s20,
  Space.s12,
  Space.s20,
  Space.s24 + MediaQuery.viewPaddingOf(context).bottom,
);

/// 빈 목록: `empty-state`와 `missing.notice`를 한 묶음으로 화면 세로 40% 지점에 둡니다.
///
/// `empty-state`가 좌우 `space.20`을 스스로 두므로 바깥 여백은 세로만 두고, notice에만
/// 좌우 `space.20`을 줘 둘의 글자 시작을 맞춥니다.
class _EmptyWithNotice extends StatelessWidget {
  const new({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.2),
      child: SingleChildScrollView(
        padding: _contentPadding(context).copyWith(left: 0, right: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: const AppGlyph(
                light: PhosphorIconsLight.receipt,
                regular: PhosphorIconsRegular.receipt,
              ),
              body: body,
              identifier: SlotIds.purchaseHistoryEmptyBody,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.s20),
              child: _MissingNotice(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseList extends ConsumerWidget {
  const new({required this.purchases});

  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final adFreeProductIds = ref.watch(adFreeProductIdsProvider);
    // 광고 제거권 줄만 있으면 스토어 이름이 필요 없어 상품 목록을 받지 않습니다.
    final storeProducts = _needsStoreNames(ref, purchases)
        ? ref.watch(storeProductsProvider).value ?? const <StoreProduct>[]
        : const <StoreProduct>[];
    // 구매 날짜는 프로필 시간대가 아니라 기기 시간대 기준입니다(spec §6).
    final timezone =
        ref.watch(deviceTimezoneNameProvider).value ?? fallbackTimezone;
    PurchaseRowData rowOf(Purchase purchase) {
      final meta = purchaseMeta(
        l10n,
        purchase,
        locale: l10n.localeName,
        timezone: timezone,
      );
      return PurchaseRowData(
        product: purchaseProductName(
          l10n,
          purchase.productId,
          adFreeProductIds: adFreeProductIds,
          storeProducts: storeProducts,
        ),
        status: purchaseStatusLabel(l10n, purchase.status),
        active: purchase.status == PurchaseStatus.active,
        purchased: meta.purchased,
        period: meta.period,
      );
    }

    return ListView(
      padding: _contentPadding(context),
      children: [
        PurchaseRowGroup(
          rows: [for (final purchase in purchases) rowOf(purchase)],
        ),
        const _MissingNotice(),
      ],
    );
  }
}

/// 결제한 상품이 안 보일 때의 안내(`purchase-history.missing.notice`).
///
/// 목록이든 빈 목록이든 바로 위 묶음과 [gap]만큼 떨어집니다.
class _MissingNotice extends StatelessWidget {
  const new();

  /// 위 묶음(`purchase-row` 카드나 `empty-state`)과의 간격.
  static const double gap = Space.s16;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: gap),
      child: Semantics(
        identifier: SlotIds.purchaseHistoryMissingNotice,
        child: Text(
          AppLocalizations.of(context).purchaseHistoryMissingNotice,
          style: tokens.typography.captionMd.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
