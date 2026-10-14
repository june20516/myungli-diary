import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';

/// 온보딩 입력의 현재 값입니다. 저장한 값이 있으면 이어서 시작합니다.
///
/// 바꿀 때마다 바로 저장하므로 앱을 껐다 켜도 입력이 남습니다.
class OnboardingDraftController extends AsyncNotifier<OnboardingDraft> {
  @override
  Future<OnboardingDraft> build() async {
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
    await ref.read(onboardingDraftStoreProvider).write(next);
    return next;
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
