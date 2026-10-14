import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 세션이 있는 사용자가 온보딩 입력을 마쳤을 때의 마무리 동작(프로필 저장 → 진입 갱신).
///
/// 미리보기를 건너뛰는 갈래에서 `onboard-gender`(한국)와 `birthplace`의 "다음"이 부릅니다.
/// `OnboardingCompleter`가 생기는 Task 17이 채웁니다. 그 전에는 부르면 [UnimplementedError]입니다.
final onboardingFinishProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => throw UnimplementedError('OnboardingCompleter를 연결하세요(Task 17).'),
);
