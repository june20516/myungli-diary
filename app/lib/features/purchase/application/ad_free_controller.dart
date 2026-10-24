import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/features/purchase/application/purchase_providers.dart';

/// `ad-free` 화면에서 살 수 있는 광고 제거권 상품(`products()`의 광고 제거권 첫 상품).
///
/// 빌드 설정의 광고 제거권 id에 드는 첫 상품이고, 없으면 목록의 첫 상품입니다. 목록이 비면
/// [UnexpectedError]입니다. 자동 재시도 없이 화면의 다시 시도로만 다시 받습니다.
final FutureProvider<StoreProduct> adFreeProductProvider =
    FutureProvider.autoDispose<StoreProduct>((ref) async {
      final products = await ref.read(purchasesProvider).products();
      final adFreeIds = ref.read(adFreeProductIdsProvider);
      for (final product in products) {
        if (adFreeIds.contains(product.id)) {
          return product;
        }
      }
      if (products.isEmpty) {
        throw UnexpectedError(StateError('살 수 있는 상품이 없음'));
      }
      return products.first;
    }, retry: (_, _) => null);

/// 광고 제거 구매(A75). 상태는 구매 중인지입니다.
///
/// 1. `Purchases.buy`: 성공이 아니면(취소·실패) 결과만 돌려줍니다. 던진 예외는 `PurchaseFailed`로
///    감쌉니다.
/// 2. 성공이면 햅틱 light, `restorePurchases`로 장부를 맞추고(웹훅 지연을 기다리지 않음),
///    `Me`를 다시 받습니다. `restorePurchases` 실패는 구매 성공으로 보고 `Me`만 받습니다.
///    예상 밖 오류는 요약만 crash 기록에 남깁니다(D64).
///
/// 구매 중에 다시 부르면 새로 사지 않고 진행 중인 시도를 돌려줍니다(두 번 누르기).
class AdFreeController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<PurchaseOutcome>? _inFlight;

  /// [productId]를 삽니다.
  Future<PurchaseOutcome> buy(String productId) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    state = true;
    // 구매 직후 화면을 떠나도 장부 맞추기와 `Me` 갱신이 끝나도록 시도가 끝날 때까지 붙들어 둡니다.
    final link = ref.keepAlive();
    final attempt = _buy(productId).whenComplete(() {
      _inFlight = null;
      if (ref.mounted) {
        state = false;
      }
      link.close();
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<PurchaseOutcome> _buy(String productId) async {
    final PurchaseOutcome outcome;
    try {
      outcome = await ref.read(purchasesProvider).buy(productId);
    } on AppError catch (error) {
      return PurchaseFailed(error);
    } on Object catch (error, stack) {
      // 계약은 실패를 PurchaseFailed로 돌려주는 것이라 예상 밖 예외는 기록하고 감쌉니다(D64).
      _recordIfUnexpected(error, stack);
      return PurchaseFailed(UnexpectedError(error));
    }
    if (outcome is! PurchaseSucceeded || !ref.mounted) {
      return outcome;
    }
    await Haptics.light();
    try {
      await ref.read(purchaseRepositoryProvider).reconcile();
    } on Object catch (error, stack) {
      _recordIfUnexpected(error, stack);
    }
    if (ref.mounted) {
      // 실패는 reloadMe가 삼킵니다.
      await ref.read(entryStateProvider.notifier).reloadMe();
    }
    return outcome;
  }

  /// AppError(오프라인, 503 등)는 기록 없이 삼키고, 예상 밖 오류만 요약을 남깁니다.
  void _recordIfUnexpected(Object error, StackTrace stack) {
    if (ref.mounted) {
      recordUnlessAppError(ref.read(crashReporterProvider), error, stack);
    }
  }
}

/// `ad-free` 화면의 구매. 화면이 보이는 동안만 둡니다.
final NotifierProvider<AdFreeController, bool> adFreeControllerProvider =
    NotifierProvider.autoDispose<AdFreeController, bool>(AdFreeController.new);
