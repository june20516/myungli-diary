import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/purchase.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/purchase/application/purchase_providers.dart';

/// 구매 내역 불러오기(A76). 화면에 들어올 때마다 한 번 아래 순서로 부릅니다.
///
/// 1. `Purchases.sync()`: 스토어 내역을 RevenueCat에 맞춥니다.
/// 2. `PurchaseRepository.reconcile()`: server 장부를 맞추고, 성공하면 `me`를 새로 받습니다.
/// 3. `PurchaseRepository.list()`: 화면에 보일 목록입니다.
///
/// 1·2의 실패는 사용자에게 알리지 않고 다음 단계로 갑니다(오프라인이어도 건너뛰지
/// 않음). 예상 밖 오류만 요약으로 crash 기록에 남깁니다(D64). 화면 상태는 3의 결과로
/// 정하므로, 3이 실패하면 그 [AppError]가 [AsyncError]로 남습니다.
final class PurchaseHistoryController extends AsyncNotifier<List<Purchase>> {
  @override
  Future<List<Purchase>> build() async {
    await _syncQuietly();
    if (!ref.mounted) {
      return const [];
    }
    await _reconcileQuietly();
    if (!ref.mounted) {
      return const [];
    }
    return await ref.read(purchaseRepositoryProvider).list();
  }

  /// 1부터 다시 합니다. 이미 불러오는 중이면 겹쳐 돌지 않도록 무시합니다.
  Future<void> retry() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> _syncQuietly() async {
    try {
      await ref.read(purchasesProvider).sync();
    } on Object catch (error, stack) {
      _recordIfUnexpected(error, stack);
    }
  }

  Future<void> _reconcileQuietly() async {
    try {
      await ref.read(purchaseRepositoryProvider).reconcile();
    } on Object catch (error, stack) {
      _recordIfUnexpected(error, stack);
      return;
    }
    if (ref.mounted) {
      // 남은 기간이 바뀔 수 있어 `me`를 다시 받습니다. 실패는 reloadMe가 삼킵니다.
      await ref.read(entryStateProvider.notifier).reloadMe();
    }
  }

  /// AppError(오프라인, 503 등)는 기록 없이 삼키고, 예상 밖 오류만 요약을 남깁니다.
  void _recordIfUnexpected(Object error, StackTrace stack) {
    final unexpected = switch (error) {
      UnexpectedError(:final cause) => cause,
      AppError() => null,
      _ => error,
    };
    if (unexpected != null && ref.mounted) {
      ref
          .read(crashReporterProvider)
          .record(CrashSummary.from(unexpected), stack);
    }
  }
}

/// 구매 내역. 자동 재시도 없이 [PurchaseHistoryController.retry]로만 다시 합니다.
final AsyncNotifierProvider<PurchaseHistoryController, List<Purchase>>
purchaseHistoryProvider = AsyncNotifierProvider.autoDispose(
  PurchaseHistoryController.new,
  retry: (_, _) => null,
);
