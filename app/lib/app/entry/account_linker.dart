import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

/// 로그인한 계정을 외부 SDK(RevenueCat, Crashlytics)에 잇고, 로그아웃하면 끊습니다.
///
/// 계정 id의 출처는 진입 계산이 내는 [meProvider] 하나입니다. 로그인 화면(계획 2)도
/// 로그인 뒤 `entryStateProvider.notifier.refresh()`를 거치므로, 세션 복원(앱을 다시 연
/// 경우)과 새 로그인이 모두 이 한 곳에서 연결됩니다. 연결: `Purchases.logIn(accountId)`,
/// `CrashReporter.setUser(accountId)`(계정 id만, D64 ②). 해제는
/// [AuthEvent.signedOut]에서 `Purchases.logOut()`, `CrashReporter.setUser(null)`
/// 입니다. 이전 실행의 SDK 계정이 남아 있을 수 있어, 이번 실행에서 연결한 적이
/// 없어도 해제합니다.
///
/// 순서가 섞이지 않게 단계를 차례로 실행하고, 실패는 요약만 보고합니다.
final class AccountLinker {
  /// [_ref]로 SDK 대역·adapter를 읽는 연결 담당을 만듭니다.
  new(this._ref);

  final Ref _ref;
  String? _linkedAccountId;
  Future<void> _queue = Future.value();

  /// 마지막 단계까지 끝나면 완료되는 Future. 테스트가 기다립니다.
  Future<void> get idle => _queue;

  /// 내 정보의 계정 id가 [accountId]가 됐습니다. 같은 계정이거나 null이면 하지 않습니다.
  ///
  /// null(진입 계산 실패, 로그아웃 상태)은 해제가 아닙니다. 해제는 [unlink]만 합니다.
  void link(String? accountId) {
    if (accountId == null || accountId == _linkedAccountId) {
      return;
    }
    _linkedAccountId = accountId;
    _enqueue(() async {
      _ref.read(crashReporterProvider).setUser(accountId);
      try {
        await _ref.read(purchasesProvider).logIn(accountId);
      } on Object {
        // 다음 진입 계산 때 다시 시도합니다.
        if (_linkedAccountId == accountId) {
          _linkedAccountId = null;
        }
        rethrow;
      }
    });
  }

  /// 로그아웃됐습니다. SDK의 계정 연결을 끊습니다.
  void unlink() {
    _linkedAccountId = null;
    _enqueue(() async {
      _ref.read(crashReporterProvider).setUser(null);
      await _ref.read(purchasesProvider).logOut();
    });
  }

  void _enqueue(Future<void> Function() step) {
    _queue = _queue.then((_) async {
      try {
        await step();
      } on Object catch (error, stack) {
        _ref
            .read(crashReporterProvider)
            .record(CrashSummary.from(error), stack);
      }
    });
  }
}

/// 계정 id 변화와 로그아웃 이벤트를 들으며 [AccountLinker]를 돌립니다. 앱 루트가 붙들어 둡니다.
final accountLinkerProvider = Provider<AccountLinker>((ref) {
  final linker = AccountLinker(ref);
  ref.listen(
    meProvider.select((me) => me?.accountId),
    (_, accountId) => linker.link(accountId),
    fireImmediately: true,
  );
  final subscription = ref
      .watch(tokenStoreProvider)
      .events
      .where((event) => event == AuthEvent.signedOut)
      .listen((_) => linker.unlink());
  ref.onDispose(subscription.cancel);
  return linker;
});
