import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

/// 로그아웃([AuthEvent.signedOut]) 뒤 이전 계정의 로컬 흔적을 정리합니다.
///
/// 어떤 경로의 로그아웃이든(refresh 거부, `getMe` 401, 삭제 대기 계정, 자발적 로그아웃)
/// `TokenStore.signOut`의 이벤트로 돕니다. 기기에는 한 번에 한 계정만 로그인하므로 계정
/// id를 기억하지 않고 모든 계정의 캐시·일기 초안과 온보딩 입력을 지웁니다
/// ([AppDatabase.clearSignedOutData]). 기기 플래그는 남기고 알림 허락 대기
/// ([notifyAskPendingKey])만 끕니다. 그래서 이번 실행에서 내 정보를 받기 전에 로그아웃돼도
/// 정리됩니다. 외부 SDK 연결 해제는 `AccountLinker`가 맡습니다.
final class SignOutCleaner {
  /// [_ref]로 DB와 보고 담당을 읽는 정리 담당을 만듭니다.
  new(this._ref);

  final Ref _ref;

  /// 정리를 하고 끝나면 돌아옵니다. 한 단계가 실패해도 나머지는 계속하고 요약만 보고합니다.
  Future<void> clean() async {
    await _guard(() => _ref.read(appDatabaseProvider).clearSignedOutData());
    // 알림 허락 대기는 그 계정의 온보딩 단계라 다음 계정에 넘기지 않습니다(A17).
    await _guard(
      () => _ref
          .read(deviceFlagsStoreProvider)
          .writeBool(notifyAskPendingKey, value: false),
    );
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
  final subscription = ref
      .watch(tokenStoreProvider)
      .events
      .where((event) => event == AuthEvent.signedOut)
      .listen((_) => unawaited(cleaner.clean()));
  ref.onDispose(subscription.cancel);
  return cleaner;
});
