import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';

/// 강제 로그아웃(refresh 거부) 뒤 이전 계정의 로컬 흔적을 정리합니다.
///
/// 정리는 로그아웃 직전 계정 id([meProvider]에서 기억)로 합니다. 로그아웃이 되면
/// 진입 계산이 다시 돌아 `meProvider`가 비므로 그 전의 값을 들고 있어야 합니다.
/// 정리 대상: 그 계정의 캐시·일기 초안·온보딩 입력(기기 플래그는 남김), 구매 계정 연결.
/// 계정을 알 수 없으면(me를 받기 전에 로그아웃) 지울 계정 데이터가 없으므로 구매 연결만 끊습니다.
final class SignOutCleaner {
  /// 기억한 계정 id를 [lastAccountId]로 읽는 정리 담당을 만듭니다.
  new(this._ref);

  final Ref _ref;

  /// 로그아웃 직전의 계정 id. 로그인한 적이 없으면 null.
  String? lastAccountId;

  /// 정리를 하고 끝나면 돌아옵니다. 한 단계가 실패해도 나머지는 계속하고 요약만 보고합니다.
  Future<void> clean() async {
    final accountId = lastAccountId;
    lastAccountId = null;
    if (accountId != null) {
      await _guard(
        () => CacheStore(
          _ref.read(appDatabaseProvider),
          accountId: accountId,
        ).clearOnSignOut(),
      );
    }
    await _guard(() => _ref.read(purchasesProvider).logOut());
    // 알림 기기 해제(deleteDevice)는 기기 id 저장이 계획 7 몫이라 계획 7에서 연결합니다.
    // 연결할 때 위처럼 `_guard`로 감싸 한 단계 실패가 나머지를 막지 않게 합니다.
  }

  Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (error, stack) {
      _ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
    }
  }
}

/// 로그아웃 이벤트를 들으며 [SignOutCleaner]를 돌립니다. 앱 루트가 붙들어 둡니다.
final signOutCleanerProvider = Provider<SignOutCleaner>((ref) {
  final cleaner = SignOutCleaner(ref);
  ref.listen(meProvider, (_, me) {
    if (me != null) {
      cleaner.lastAccountId = me.accountId;
    }
  }, fireImmediately: true);
  final subscription = ref
      .watch(tokenStoreProvider)
      .events
      .where((event) => event == AuthEvent.signedOut)
      .listen((_) => unawaited(cleaner.clean()));
  ref.onDispose(subscription.cancel);
  return cleaner;
});
