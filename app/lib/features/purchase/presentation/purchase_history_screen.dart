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

/// 구매 한 건의 `purchase-row` meta 한 줄: 구매일 + 구분자 + 사용 기간.
///
/// 날짜는 [timezone]의 달력 날짜를 [locale]의 짧은 날짜로 보입니다. 기간이 없으면 구매일만
/// 보입니다.
String purchaseMeta(
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

  final purchased = l10n.purchaseMetaPurchased(date(purchase.purchasedAt));
  final period = purchase.period;
  if (period == null) {
    return purchased;
  }
  return '$purchased${l10n.purchaseMetaSeparator}'
      '${l10n.purchaseMetaPeriod(date(period.startsAt), date(period.endsAt))}';
}

/// 스토어 상품 목록(상품 이름용). 받지 못하면 빈 목록이라 이름이 상품 id로 보입니다.
final FutureProvider<List<StoreProduct>> storeProductsProvider =
    FutureProvider.autoDispose<List<StoreProduct>>((ref) async {
      try {
        return await ref.watch(purchasesProvider).products();
      } on Object {
        return const [];
      }
    });

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
                  value: history,
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
                  empty: Column(
                    children: [
                      Expanded(
                        child: EmptyState(
                          icon: const AppGlyph(
                            light: PhosphorIconsLight.receipt,
                            regular: PhosphorIconsRegular.receipt,
                          ),
                          body: l10n.purchaseHistoryEmptyBody,
                          identifier: SlotIds.purchaseHistoryEmptyBody,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          Space.s20,
                          Space.s16,
                          Space.s20,
                          Space.s24 + MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: const _MissingNotice(),
                      ),
                    ],
                  ),
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

class _PurchaseList extends ConsumerWidget {
  const new({required this.purchases});

  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final adFreeProductIds = ref.watch(adFreeProductIdsProvider);
    final storeProducts = ref.watch(storeProductsProvider).value ?? const [];
    final timezone = ref.watch(profileTimezoneProvider);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        Space.s20,
        Space.s12,
        Space.s20,
        Space.s24 + bottom,
      ),
      children: [
        PurchaseRowGroup(
          rows: [
            for (final purchase in purchases)
              PurchaseRowData(
                product: purchaseProductName(
                  l10n,
                  purchase.productId,
                  adFreeProductIds: adFreeProductIds,
                  storeProducts: storeProducts,
                ),
                status: purchaseStatusLabel(l10n, purchase.status),
                active: purchase.status == PurchaseStatus.active,
                meta: purchaseMeta(
                  l10n,
                  purchase,
                  locale: l10n.localeName,
                  timezone: timezone,
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.s16),
        const _MissingNotice(),
      ],
    );
  }
}

/// 결제한 상품이 안 보일 때의 안내(`purchase-history.missing.notice`).
class _MissingNotice extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      identifier: SlotIds.purchaseHistoryMissingNotice,
      child: Text(
        AppLocalizations.of(context).purchaseHistoryMissingNotice,
        style: tokens.typography.captionMd.copyWith(
          color: tokens.colors.textSecondary,
        ),
      ),
    );
  }
}
