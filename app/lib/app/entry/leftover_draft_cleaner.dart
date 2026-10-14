import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';

/// 프로필이 있는 계정의 진입 갈래. 이 갈래에서는 온보딩 입력을 읽는 경로가 없습니다.
const Set<EntryState> profiledEntries = {
  EntryState.notifyAskRequired,
  EntryState.adConsentRequired,
  EntryState.ready,
};

/// 진입이 프로필 있는 갈래([profiledEntries])로 계산되면 남은 온보딩 입력을 지웁니다.
///
/// 로그인 직후 입력 삭제가 실패했거나(계정 확인 통신 오류, 토큰 저장 뒤 앱 종료) 다른 경로로
/// 입력이 남아도, 프로필이 있는 계정에서 옛 입력이 다시 쓰이지 않게 합니다(I1). 프로필
/// 수정 모드(A19)는 입력을 쓰지 않으므로 영향이 없습니다. 앱 루트가 붙들어 둡니다.
final leftoverDraftCleanerProvider = Provider<void>((ref) {
  ref.listen<EntryState?>(entryProvider, (_, entry) {
    if (profiledEntries.contains(entry)) {
      unawaited(_clearLeftover(ref));
    }
  }, fireImmediately: true);
});

Future<void> _clearLeftover(Ref ref) async {
  try {
    final draft = await ref.read(onboardingDraftProvider.future);
    if (!ref.mounted || draft == const OnboardingDraft()) {
      return;
    }
    await ref.read(onboardingDraftProvider.notifier).clear();
  } on Object catch (error, stack) {
    if (!ref.mounted) return;
    // 지우지 못해도 진입은 막지 않습니다. 입력은 로그아웃 때 다시 지웁니다(D64 ②: 값은 싣지 않음).
    ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
  }
}
