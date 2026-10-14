import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/auth/data/consent_repository.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';

/// 약관 동의 저장소.
final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(ref.watch(restClientProvider)),
);

/// 동의한 버전이 현재 버전과 달라 문서를 다시 받아야 하는 오류인지(422 `consent.version_mismatch`).
bool isConsentVersionMismatch(AppError error) =>
    error is ProblemError && error.code == 'consent.version_mismatch';

/// 약관 동의 화면의 동작입니다(D50).
///
/// 동의에 성공하면 온보딩 입력이 완전할 때(미리보기를 거친 새 계정) **프로필을 먼저 저장한 뒤**
/// 진입을 다시 계산합니다. 먼저 갱신하면 `profileRequired`가 되어 `onboard-call`로 튕기기
/// 때문입니다. 입력이 없으면 진입만 다시 계산해 `onboard-call`로 갑니다. 이동은 라우터
/// redirect가 정합니다.
///
/// 처리 중에 다시 부르면 새 요청 없이 진행 중인 시도의 결과를 돌려줍니다.
class ConsentController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<AppError?>? _inFlight;

  /// [documents]에 동의합니다. 동의가 실패하면 그 오류를, 아니면 null을 돌려줍니다.
  ///
  /// 버전이 바뀌었으면(`consent.version_mismatch`) 내 정보를 다시 받아 새 버전을 띄웁니다.
  /// 동의 뒤 프로필 저장이 실패해도 동의는 끝났으므로 진입을 다시 계산해 `onboard-call`로
  /// 보냅니다. 입력 오류면 `onboard-call`이 보일 안내를 남기고, 그 밖의 실패는
  /// `onboard-call`이 한 번 다시 저장합니다.
  Future<AppError?> agree(List<ConsentDocument> documents) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    state = const AsyncLoading();
    final attempt = _attempt(documents).whenComplete(() {
      _inFlight = null;
      if (ref.mounted) {
        state = const AsyncData(null);
      }
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<AppError?> _attempt(List<ConsentDocument> documents) async {
    // 진입 갱신으로 화면이 닫혀 이 controller가 버려져도 끝맺도록 의존성을 먼저 잡아 둡니다.
    final repository = ref.read(consentRepositoryProvider);
    final entry = ref.read(entryStateProvider.notifier);
    final completer = ref.read(onboardingCompleterProvider);
    final notice = ref.read(onboardingRejectionNoticeProvider.notifier);
    final crashReporter = ref.read(crashReporterProvider);
    try {
      await repository.agree(documents);
    } on AppError catch (error) {
      if (isConsentVersionMismatch(error)) {
        await entry.refresh();
      }
      return error;
    }
    if (await completer.isReady()) {
      try {
        await completer.complete();
        return null;
      } on OnboardingInputRejected catch (rejected) {
        notice.pending = rejected.error;
      } on AppError {
        // 입력 오류(422)가 아닌 server·통신 실패는 모두 여기로 옵니다. 동의는 끝났으므로
        // 진입을 다시 계산하고, onboard-call이 진입할 때 한 번 다시 저장합니다.
      } on Object catch (error, stack) {
        // 진단을 위해 요약(오류 타입)만 보고합니다(D64 ②: 출생 정보·호칭은 싣지 않음).
        crashReporter.record(CrashSummary.from(error), stack);
      }
    }
    await entry.refresh();
    return null;
  }
}

/// 약관 동의 화면 동작. 화면이 보이는 동안만 둡니다.
final AsyncNotifierProvider<ConsentController, void> consentControllerProvider =
    AsyncNotifierProvider.autoDispose<ConsentController, void>(
      ConsentController.new,
    );
