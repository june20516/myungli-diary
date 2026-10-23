import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/features/purchase/data/ad_free_product_ids.dart';
import 'package:myungli_diary/features/purchase/data/purchase_repository.dart';

/// 광고 제거권 상품 id. 빌드 설정 `AD_FREE_PRODUCT_IDS`(쉼표로 구분)에서 읽습니다.
final adFreeProductIdsProvider = Provider<Set<String>>(
  (ref) => adFreeProductIdsFrom(
    const String.fromEnvironment('AD_FREE_PRODUCT_IDS'),
    mode: ref.watch(apiModeProvider),
  ),
);

/// 구매 저장소. 로그인 여부는 확인하지 않으므로 부르는 쪽이 로그인한 계정에서만 씁니다.
final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(ref.watch(restClientProvider)),
);

/// 스토어 상품 목록(구매 내역의 상품 이름용). 받지 못하면 빈 목록이라 이름이 상품 id로 보입니다.
///
/// [AppError]는 기록 없이 빈 목록으로, 예상 밖 오류만 요약을 crash 기록에 남깁니다(D64).
final FutureProvider<List<StoreProduct>> storeProductsProvider =
    FutureProvider.autoDispose<List<StoreProduct>>((ref) async {
      try {
        return await ref.watch(purchasesProvider).products();
      } on AppError {
        return const [];
      } on Object catch (error, stack) {
        if (ref.mounted) {
          ref
              .read(crashReporterProvider)
              .record(CrashSummary.from(error), stack);
        }
        return const [];
      }
    });
