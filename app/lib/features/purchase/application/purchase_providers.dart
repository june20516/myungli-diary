import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
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
