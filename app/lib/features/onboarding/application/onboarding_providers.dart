import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';

/// 온보딩 입력의 현재 값입니다. 저장한 값이 있으면 이어서 시작합니다.
///
/// 바꿀 때마다 바로 저장하므로 앱을 껐다 켜도 입력이 남습니다.
class OnboardingDraftController extends AsyncNotifier<OnboardingDraft> {
  @override
  Future<OnboardingDraft> build() async {
    final subscription = ref
        .watch(tokenStoreProvider)
        .events
        .where((event) => event == AuthEvent.signedOut)
        .listen((_) => unawaited(_discardOnSignOut()));
    ref.onDispose(subscription.cancel);
    final startGeneration = _generation;
    final saved = await ref.read(onboardingDraftStoreProvider).read();
    // 읽는 중에 로그아웃·clear가 있었으면 읽은 행은 이전 값이라 올리지 않습니다.
    if (_generation != startGeneration) {
      return const OnboardingDraft();
    }
    return saved ?? const OnboardingDraft();
  }

  /// [cb]로 입력을 바꾸고 바로 저장합니다.
  ///
  /// `AsyncNotifier.update`(보호된 메서드)를 같은 시그니처로 열어 저장을 더했습니다.
  /// [cb]가 도는 동안 로그아웃·[clear]가 일어나면(세대가 바뀌면) 결과를 버리고 현재 상태를
  /// 돌려줍니다. 상태는 쓰기 전에 바뀌므로, 저장이 실패하면 예외만 전파됩니다.
  @override
  Future<OnboardingDraft> update(
    FutureOr<OnboardingDraft> Function(OnboardingDraft previousState) cb, {
    FutureOr<OnboardingDraft> Function(Object err, StackTrace stackTrace)?
    onError,
  }) async {
    final startGeneration = _generation;
    final next = await future.then(cb, onError: onError);
    if (_generation != startGeneration) {
      return state.value ?? const OnboardingDraft();
    }
    state = AsyncData(next);
    await _enqueue(() async {
      if (_generation == startGeneration) {
        await ref.read(onboardingDraftStoreProvider).write(next);
      }
    });
    return next;
  }

  /// 로그아웃·[clear]마다 올라가는 세대 번호. 이전 세대의 갱신을 버리는 기준입니다.
  int _generation = 0;

  Future<void> _lastTask = Future<void>.value();

  /// 앞선 저장 작업이 끝난 뒤에 [task]를 돌려 저장 순서를 호출 순서로 맞춥니다.
  Future<void> _enqueue(Future<void> Function() task) {
    final next = _lastTask.catchError((Object _) {}).then((_) => task());
    _lastTask = next;
    return next;
  }

  /// 입력을 비우고 저장 행 삭제를 쓰기 큐 맨 뒤에 둡니다.
  Future<void> _discard() {
    _generation++;
    state = const AsyncData(OnboardingDraft());
    return _enqueue(() => ref.read(onboardingDraftStoreProvider).clear());
  }

  /// 로그아웃하면 메모리 입력과 저장 행을 비웁니다. 실패해도 미처리 오류로 남기지 않고
  /// 오류 요약만 기록합니다(D64 ②: 입력 값은 싣지 않음).
  Future<void> _discardOnSignOut() async {
    try {
      await _discard();
    } on Object catch (error, stack) {
      ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
    }
  }

  /// 저장한 입력과 현재 값을 지웁니다(프로필 저장에 성공한 뒤).
  Future<void> clear() => _discard();
}

/// 온보딩 입력 provider.
final onboardingDraftProvider =
    AsyncNotifierProvider<OnboardingDraftController, OnboardingDraft>(
      OnboardingDraftController.new,
    );
