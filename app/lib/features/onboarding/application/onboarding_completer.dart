import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/profile_input.dart';
import 'package:myungli_diary/core/api/gen/model/profile_response.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// server가 온보딩 입력을 받아들이지 않았습니다(422 `birth.*`·`date.*`·`name.*`·
/// `request.inconsistent`). 입력은 남아 있어 `onboard-call`부터 고칠 수 있습니다.
final class OnboardingInputRejected implements Exception {
  /// server 오류를 담습니다.
  const new(this.error);

  /// server 오류. 사용자 문구는 `errorMessage`로 만듭니다.
  final AppError error;
}

/// 입력을 고쳐야 하는 422인지. 프로필 저장의 입력 검사 오류입니다.
bool isOnboardingInputProblem(AppError error) =>
    error is ProblemError &&
    error.status == 422 &&
    (error.code.startsWith('birth.') ||
        error.code.startsWith('date.') ||
        error.code.startsWith('name.') ||
        error.code == 'request.inconsistent');

/// 마무리 실패 [error]를 안내할 [AppError]로 바꿉니다.
AppError onboardingErrorOf(Object error) => switch (error) {
  OnboardingInputRejected(:final error) => error,
  final AppError error => error,
  _ => UnexpectedError(error),
};

/// 온보딩 입력을 프로필로 저장하고 계정 만들기를 마무리합니다(A17·A18).
///
/// 미리보기를 거친 새 계정(약관 동의 직후)과 로그인한 채 온보딩을 마친 계정
/// (`onboard-gender`·`birthplace`의 다음), 프로필 저장 전에 앱이 꺼졌던 계정
/// (`onboard-call` 진입)이 모두 여기를 거칩니다.
///
/// 순서: 프로필 저장 → 알림 허락 대기([notifyAskPendingKey]) → 입력 삭제 → 진입 갱신.
/// 플래그를 삭제보다 먼저 써서, 저장 뒤 앱이 꺼져도 notify-ask를 건너뛰지 않습니다.
/// 진입 갱신이 마지막이라 라우터 redirect가 `notify-ask`로 보냅니다.
///
/// **프로필이 없는 계정에서만** 저장합니다(`createProfile`은 PUT이라 있는 프로필을 덮어씀).
/// 부르는 쪽이 진입 `profileRequired`(또는 동의 전 `hasProfile == false`)를 확인하고, 여기서도
/// 한 번 더 막습니다. 알림 허락 대기가 켜져 있으면 이 계정의 프로필은 이미 저장된 것이라
/// 다시 저장하지 않고 진입만 다시 계산합니다(앞선 진입 갱신이 실패한 뒤 다시 누른 경우).
final class OnboardingCompleter {
  /// 의존성을 받습니다. 함수 인자는 부를 때마다 현재 값을 읽습니다.
  const new({
    required this._createProfile,
    required this._readDraft,
    required this._clearDraft,
    required this._language,
    required this._deviceRegionIsKorea,
    required this._deviceTimezone,
    required this._flags,
    required this._needsProfile,
    required this._refreshEntry,
    required this._crashReporter,
  });

  final Future<ProfileResponse> Function(ProfileInput input) _createProfile;
  final Future<OnboardingDraft> Function() _readDraft;
  final Future<void> Function() _clearDraft;
  final Language _language;
  final bool _deviceRegionIsKorea;
  final Future<String> Function() _deviceTimezone;
  final DeviceFlagsStore _flags;
  final bool Function() _needsProfile;
  final Future<AppError?> Function() _refreshEntry;
  final CrashReporter _crashReporter;

  /// 프로필을 만들 만큼 입력을 다 받았는지. 입력을 읽지 못하면 false입니다.
  Future<bool> isReady() async {
    try {
      final draft = await _readDraft();
      return draft.isCompleteFor(deviceRegionIsKorea: _deviceRegionIsKorea);
    } on Object {
      return false;
    }
  }

  /// 입력으로 프로필을 만들고 마무리합니다.
  ///
  /// 입력 오류(422)면 입력을 남기고 [OnboardingInputRejected]를 던집니다. 그 밖의 저장 실패는
  /// [AppError] 그대로이고, 어느 쪽이든 진입은 다시 계산하지 않습니다. 저장 뒤 진입 계산이
  /// 실패하면 그 [AppError]를 던집니다. 프로필이 있는 계정이면 [StateError]입니다.
  Future<void> complete() async {
    if (await _flags.readBool(notifyAskPendingKey)) {
      // 이 계정의 프로필은 이미 저장했습니다(로그아웃하면 꺼지는 플래그). 갱신만 다시 합니다.
      await _refreshOrThrow();
      return;
    }
    if (!_needsProfile()) {
      throw StateError('프로필이 있는 계정에서는 온보딩 입력으로 프로필을 만들지 않습니다.');
    }
    final draft = await _readDraft();
    final honorific = draft.honorific;
    if (honorific == null ||
        !draft.isCompleteFor(deviceRegionIsKorea: _deviceRegionIsKorea)) {
      throw StateError('온보딩 입력을 다 받기 전에는 프로필을 만들 수 없습니다.');
    }
    final input = ProfileInput(
      honorific: honorific.trim(),
      language: _language,
      currentTimezone: await _deviceTimezone(),
      birth: draft.toBirth(deviceRegionIsKorea: _deviceRegionIsKorea),
      notification: NotificationSetting(
        status: NotificationSettingStatusEnum.notAsked,
      ),
    );
    try {
      await _createProfile(input);
    } on AppError catch (error) {
      if (isOnboardingInputProblem(error)) {
        throw OnboardingInputRejected(error);
      }
      rethrow;
    }
    // 입력 삭제보다 먼저 켭니다. 그 사이 앱이 꺼져도 다음 진입이 notify-ask를 거칩니다.
    await _flags.writeBool(notifyAskPendingKey, value: true);
    try {
      await _clearDraft();
    } on Object catch (error, stack) {
      // 지우지 못해도 프로필은 저장됐으니 마무리합니다. 입력은 로그아웃 때 다시 지웁니다
      // (D64 ②: 값은 싣지 않음).
      _crashReporter.record(CrashSummary.from(error), stack);
    }
    await _refreshOrThrow();
  }

  Future<void> _refreshOrThrow() async {
    final error = await _refreshEntry();
    if (error != null) {
      throw error;
    }
  }
}

/// 온보딩 마무리 동작.
final onboardingCompleterProvider = Provider<OnboardingCompleter>(
  (ref) => OnboardingCompleter(
    createProfile: ref.watch(profileRepositoryProvider).create,
    readDraft: () => ref.read(onboardingDraftProvider.future),
    clearDraft: () => ref.read(onboardingDraftProvider.notifier).clear(),
    language: ref.watch(appLanguageProvider),
    deviceRegionIsKorea: ref.watch(deviceRegionIsKoreaProvider),
    deviceTimezone: () => ref.read(deviceTimezoneNameProvider.future),
    flags: ref.watch(deviceFlagsStoreProvider),
    needsProfile: () => ref.read(meProvider)?.hasProfile == false,
    refreshEntry: () => ref.read(entryStateProvider.notifier).refresh(),
    crashReporter: ref.watch(crashReporterProvider),
  ),
);

/// 프로필 저장이 입력 오류(422)로 실패했을 때 `onboard-call`이 보일 안내.
///
/// 약관 동의 직후 저장(consent)과 로그인한 채 마친 온보딩의 저장(`onboard-gender`·
/// `birthplace`·`onboard-call`의 다음)이 남기고 `onboard-call`로 보냅니다. `onboard-call`이
/// 한 번 꺼내, 호칭 오류(`name.*`, 필드 `/honorific`)는 입력 칸 아래 오류 줄로, 그 밖은
/// toast로 보입니다. 남아 있는 동안 `onboard-call`은 같은 입력으로 다시 저장하지 않습니다.
/// 로그아웃하면 비웁니다(다른 계정에 이전 계정의 안내가 뜨지 않게).
class OnboardingRejectionNotice extends Notifier<AppError?> {
  @override
  AppError? build() {
    final subscription = ref
        .watch(tokenStoreProvider)
        .events
        .where((event) => event == AuthEvent.signedOut)
        .listen((_) => state = null);
    ref.onDispose(subscription.cancel);
    return null;
  }

  /// 보일 안내를 남깁니다.
  // riverpod_lint는 Notifier의 공개 setter를 막고 use_setters_to_change_properties는
  // 한 줄 대입 메서드를 setter로 바꾸라 하여 부딪힙니다. 여기서는 Riverpod 쪽을 따릅니다.
  // ignore: use_setters_to_change_properties
  void leave(AppError error) => state = error;

  /// 남은 안내를 꺼내고 비웁니다. 없으면 null입니다.
  AppError? take() {
    final error = state;
    state = null;
    return error;
  }
}

/// 프로필 저장의 입력 오류 안내.
final onboardingRejectionNoticeProvider =
    NotifierProvider<OnboardingRejectionNotice, AppError?>(
      OnboardingRejectionNotice.new,
    );
