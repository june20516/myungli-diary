import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';

/// 온보딩 첫 단계(`onboard-call`)로 돌아갑니다. 입력은 초안에 남아 있어 채워진 채로 열립니다.
///
/// 스택에 `onboard-call`이 있으면 거기까지 pop해 앞 화면(welcome 등)을 보존하고, 없으면(딥링크,
/// 갈래의 첫 화면이 다른 경우) 그 경로로 이동합니다. 이미 `onboard-call`이면 그대로입니다.
void goBackToOnboardCall(BuildContext context) {
  final router = GoRouter.of(context);
  final target = pathOf(ScreenIds.onboardCall);
  final inStack = router.routerDelegate.currentConfiguration.matches.any(
    (match) => match.matchedLocation == target,
  );
  if (!inStack) {
    context.go(target);
    return;
  }
  Navigator.of(context)
      .popUntil((route) => route.settings.name == ScreenIds.onboardCall);
}

/// 프로필 저장의 입력 오류(422) [error]를 `onboard-call`에서 고치게 합니다.
///
/// `onboard-call`로 돌아간 뒤 안내([onboardingRejectionNoticeProvider])를 남깁니다. 약관 동의
/// 직후 저장이 실패한 갈래와 같은 동작입니다(입력 오류는 첫 단계부터 고침). `onboard-call`이
/// 호칭 오류는 칸 아래 오류 줄로, 그 밖은 toast로 보입니다.
void returnToOnboardCallWith(
  BuildContext context,
  WidgetRef ref,
  AppError error,
) {
  // 이동하면 이 화면이 닫혀 ref를 쓸 수 없으므로 먼저 잡아 둡니다.
  final notice = ref.read(onboardingRejectionNoticeProvider.notifier);
  goBackToOnboardCall(context);
  notice.pending = error;
}
