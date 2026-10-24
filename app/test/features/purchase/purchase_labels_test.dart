import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_status.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/features/purchase/model/purchase_labels.dart';

void main() {
  final l10n = AppLocalizationsKo();
  const adFreeIds = {'ad_free_1month'};

  test('광고 제거권 id면 writing 이름', () {
    final name = purchaseProductName(
      l10n,
      'ad_free_1month',
      adFreeProductIds: adFreeIds,
      storeProducts: const [
        StoreProduct(id: 'ad_free_1month', title: '다른 이름', priceLabel: '가격'),
      ],
    );
    expect(name, '광고 제거 1개월');
  });

  test('목록에 없으면 스토어 title', () {
    final name = purchaseProductName(
      l10n,
      'other',
      adFreeProductIds: adFreeIds,
      storeProducts: const [
        StoreProduct(id: 'other', title: '스토어 이름', priceLabel: '가격'),
      ],
    );
    expect(name, '스토어 이름');
  });

  test('스토어에도 없으면 상품 id 그대로', () {
    final name = purchaseProductName(
      l10n,
      'unknown_id',
      adFreeProductIds: adFreeIds,
      storeProducts: const [],
    );
    expect(name, 'unknown_id');
  });

  test('상태 낱말 네 개와 owned·모르는 값은 null', () {
    expect(purchaseStatusLabel(l10n, PurchaseStatus.active), '사용 중');
    expect(purchaseStatusLabel(l10n, PurchaseStatus.pending), '사용 전');
    expect(purchaseStatusLabel(l10n, PurchaseStatus.expired), '만료');
    expect(purchaseStatusLabel(l10n, PurchaseStatus.refunded), '환불');
    expect(purchaseStatusLabel(l10n, PurchaseStatus.owned), isNull);
    expect(
      purchaseStatusLabel(l10n, PurchaseStatus.unknownDefaultOpenApi),
      isNull,
    );
  });
}
