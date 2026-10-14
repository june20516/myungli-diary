import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/token_store.dart';
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
    final saved = await ref.read(onboardingDraftStoreProvider).read();
    return saved ?? const OnboardingDraft();
  }

  /// [cb]로 입력을 바꾸고 바로 저장합니다.
  ///
  /// `AsyncNotifier.update`(보호된 메서드)를 같은 시그니처로 열어 저장을 더했습니다.
  @override
  Future<OnboardingDraft> update(
    FutureOr<OnboardingDraft> Function(OnboardingDraft previousState) cb, {
    FutureOr<OnboardingDraft> Function(Object err, StackTrace stackTrace)?
    onError,
  }) async {
    final next = await super.update(cb, onError: onError);
    await _enqueueWrite(next);
    return next;
  }

  /// 앞선 쓰기가 끝난 뒤에 쓰도록 이어 붙여 저장 순서를 호출 순서로 맞춥니다.
  ///
  /// 상태는 쓰기 전에 이미 바뀌므로, 저장이 실패하면 예외만 전파됩니다.
  Future<void> _enqueueWrite(OnboardingDraft draft) {
    final write = _lastWrite
        .catchError((Object _) {})
        .then((_) => ref.read(onboardingDraftStoreProvider).write(draft));
    _lastWrite = write;
    return write;
  }

  Future<void> _lastWrite = Future<void>.value();

  /// 로그아웃하면 메모리 입력을 비웁니다(DB 정리와 별개로 이전 값이 다시 쓰이지 않게).
  Future<void> _discardOnSignOut() async {
    state = const AsyncData(OnboardingDraft());
    await ref.read(onboardingDraftStoreProvider).clear();
  }

  /// 저장한 입력과 현재 값을 지웁니다(프로필 저장에 성공한 뒤).
  Future<void> clear() async {
    await ref.read(onboardingDraftStoreProvider).clear();
    state = const AsyncData(OnboardingDraft());
  }
}

/// 온보딩 입력 provider.
final onboardingDraftProvider =
    AsyncNotifierProvider<OnboardingDraftController, OnboardingDraft>(
      OnboardingDraftController.new,
    );
