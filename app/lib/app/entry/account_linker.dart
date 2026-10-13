import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

/// 로그인한 계정을 외부 SDK(RevenueCat, Crashlytics)에 잇고, 로그아웃하면 끊습니다.
///
/// 계정 id의 출처는 진입 계산 결과(`entryStateProvider`, [meProvider]와 같은 값)
/// 하나입니다. 로그인 화면(계획 2)도 로그인 뒤 `entryStateProvider.notifier
/// .refresh()`를 거치므로, 세션 복원(앱을 다시 연 경우)과 새 로그인이 모두 이 한
/// 곳에서 연결됩니다. 연결: `Purchases.logIn(accountId)`,
/// `CrashReporter.setUser(accountId)`(계정 id만, D64 ②). 연결이 실패하면 다음 진입
/// 계산이나 앱 재개 때 다시 시도합니다. 해제는 [AuthEvent.signedOut]에서
/// `Purchases.logOut()`, `CrashReporter.setUser(null)`입니다. 이전 실행의 SDK
/// 계정이 남아 있을 수 있어, 이번 실행에서 연결한 적이 없어도 해제합니다.
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

  /// 내 정보의 계정 id가 [accountId]입니다. 이미 연결된 계정이거나 null이면 하지 않습니다.
  ///
  /// 진입 계산이 끝날 때마다와 앱이 다시 앞으로 올 때 불리므로, 연결이 실패했으면 그때
  /// 다시 시도합니다. null(로그아웃 상태)은 해제가 아닙니다. 해제는 [unlink]만 합니다.
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
        // 다음 진입 계산이나 앱 재개 때 다시 시도합니다.
        if (_linkedAccountId == accountId) {
          _linkedAccountId = null;
        }
        rethrow;
      }
    });
  }

  /// 계산이 끝난 진입 결과([entry])의 계정으로 [link]합니다. 계산 전·실패·재계산 중이면
  /// 하지 않습니다(재계산 중의 이전 값은 로그아웃 직후의 옛 계정일 수 있음).
  void linkFromEntry(AsyncValue<EntrySnapshot> entry) {
    if (entry case AsyncData(:final value, isLoading: false)) {
      link(value.me?.accountId);
    }
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
  // 계산이 끝날 때마다(같은 계정이어도) 부릅니다. 연결이 실패했으면 다음 진입 계산에서
  // 다시 시도하고, 이미 연결된 계정이면 link가 거릅니다. Riverpod은 재계산 중의 이전
  // 값을 `isLoading`인 AsyncData로 내므로 linkFromEntry가 거릅니다.
  ref.listen(
    entryStateProvider,
    (_, next) => linker.linkFromEntry(next),
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
