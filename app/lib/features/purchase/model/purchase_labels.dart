import 'package:myungli_diary/core/api/gen/model/purchase_status.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/purchases.dart';

/// 구매 내역에 보일 상품 이름.
///
/// 광고 제거권([adFreeProductIds])이면 app 문구, 아니면 스토어의 현지화된 이름
/// ([storeProducts]의 `title`)이고, 스토어에도 없으면 상품 id 그대로입니다(D88).
String purchaseProductName(
  AppLocalizations l10n,
  String productId, {
  required Set<String> adFreeProductIds,
  required List<StoreProduct> storeProducts,
}) {
  if (adFreeProductIds.contains(productId)) {
    return l10n.purchaseProductAdFreeMonth;
  }
  for (final product in storeProducts) {
    if (product.id == productId) {
      return product.title;
    }
  }
  return productId;
}

/// 기간권 구매 상태 낱말. 낱말이 없는 상태(`owned`, 모르는 값)는 null입니다.
String? purchaseStatusLabel(AppLocalizations l10n, PurchaseStatus status) =>
    switch (status) {
      PurchaseStatus.active => l10n.purchaseStatusActive,
      PurchaseStatus.pending => l10n.purchaseStatusPending,
      PurchaseStatus.expired => l10n.purchaseStatusExpired,
      PurchaseStatus.refunded => l10n.purchaseStatusRefunded,
      PurchaseStatus.owned || PurchaseStatus.unknownDefaultOpenApi => null,
    };
