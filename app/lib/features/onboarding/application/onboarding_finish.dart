import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';

/// 세션이 있는 사용자가 온보딩 입력을 마쳤을 때의 마무리 동작(프로필 저장 → 진입 갱신).
///
/// 미리보기를 건너뛰는 갈래에서 `onboard-gender`(한국)와 `birthplace`의 "다음"이 부릅니다.
/// [OnboardingCompleter.complete]이고, 입력 오류면 [OnboardingInputRejected]를 던집니다.
final onboardingFinishProvider = Provider<Future<void> Function()>(
  (ref) => ref.watch(onboardingCompleterProvider).complete,
);

/// 온보딩 입력을 마치면 미리보기 없이 프로필을 저장하는지. 로그인했고 프로필이 없는 계정
/// (진입 `profileRequired`)일 때만 true입니다.
///
/// 세션만으로 정하지 않습니다. 프로필이 있는 계정이 저장하면 사주를 덮어쓰기 때문입니다(I1).
final finishesWithoutPreviewProvider = Provider<bool>(
  (ref) => ref.watch(entryProvider) == EntryState.profileRequired,
);
