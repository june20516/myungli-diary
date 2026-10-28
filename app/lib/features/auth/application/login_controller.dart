import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/sign_out.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/login_response.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/auth/application/login_completing.dart';
import 'package:myungli_diary/features/auth/application/provider_authenticator.dart';
import 'package:myungli_diary/features/auth/data/auth_repository.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';

/// 로그인 저장소.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(restClientProvider)),
);

/// 로그인 시도 한 번의 결과입니다.
@immutable
sealed class LoginOutcome {
  const new();
}

/// 로그인했고 토큰을 저장했으며 진입 갈래를 다시 계산했습니다.
///
/// 토큰 저장 뒤 진입 계산이 실패하면 [LoginFailed]로 돌려줍니다(화면이 안내하고 다시 시도를 받음).
final class LoginSucceeded extends LoginOutcome {
  /// server 응답을 담습니다.
  const new(this.response);

  /// server 응답.
  final LoginResponse response;
}

/// 사용자가 제공자 로그인 창을 닫았습니다(카카오·iOS Apple).
final class LoginCancelled extends LoginOutcome {
  /// 취소.
  const new();
}

/// 제공자 adapter 또는 server 요청이 실패했습니다.
final class LoginFailed extends LoginOutcome {
  /// 실패 이유를 담습니다.
  const new(this.error);

  /// 실패 이유.
  final AppError error;
}

/// Android Apple 웹 흐름의 복귀가 실패를 알렸습니다(취소·state 불일치 등). server는 부르지 않았습니다.
final class AppleWebFailed extends LoginOutcome {
  /// 실패 이유를 담습니다.
  const new(this.error);

  /// 실패 이유.
  final AppleWebError error;
}

/// 사주가 저장된 계정이라 온보딩 입력을 쓰지 않는다는 안내(`login.discard.notice`)를 보이고
/// 닫힐 때까지 기다립니다.
typedef DiscardNotice = Future<void> Function();

/// 제공자 로그인부터 server 로그인까지 한 번 합니다. 원문 nonce를 받습니다.
typedef _ProviderLogin = Future<LoginOutcome> Function(String rawNonce);

/// 로그인 화면의 동작입니다(D55, Issue #100·#114).
///
/// 시도마다 새 원문 nonce 하나를 만들어 adapter(해시는 adapter가 만듦)와 server에 같은 값을
/// 넘깁니다. 성공하면 토큰을 저장하고 진입 갈래를 다시 계산합니다. 이동은 라우터 redirect가
/// 정합니다(새 계정 → consent, 사주가 저장된 계정 → 광고 동의 → today).
///
/// 처리 중에 다시 부르면 새 요청 없이 진행 중인 시도의 결과를 돌려줍니다.
class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<LoginOutcome>? _inFlight;

  /// [provider]로 로그인합니다. Apple은 Android면 웹 흐름(교환 코드), 그 밖(iOS)은 네이티브입니다.
  ///
  /// 사주가 저장된 기존 계정인데 온보딩 입력이 남아 있으면 [showDiscardNotice]를 기다린 뒤
  /// 입력을 지웁니다.
  Future<LoginOutcome> signIn(
    SocialProvider provider, {
    DiscardNotice? showDiscardNotice,
  }) {
    final authenticator = ref.read(providerAuthenticatorProvider);
    final repository = ref.read(authRepositoryProvider);
    return _once((rawNonce) async {
      final result = await authenticator.authenticate(
        provider,
        rawNonce: rawNonce,
      );
      return switch (result) {
        ProviderAuthenticated(:final proof) => LoginSucceeded(
          await repository.login(proof),
        ),
        ProviderAppleWebFailed(:final error) => AppleWebFailed(error),
      };
    }, showDiscardNotice);
  }

  /// 진행 중인 시도가 없을 때만 [login]을 시작합니다.
  Future<LoginOutcome> _once(_ProviderLogin login, DiscardNotice? notice) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    state = const AsyncLoading();
    final attempt = _attempt(login, notice).whenComplete(() {
      _inFlight = null;
      if (ref.mounted) {
        state = const AsyncData(null);
      }
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<LoginOutcome> _attempt(
    _ProviderLogin login,
    DiscardNotice? notice,
  ) async {
    // 화면이 닫혀 이 controller가 버려져도 시작한 로그인은 끝맺도록 의존성을 먼저 잡아 둡니다.
    final rawNonce = ref.read(nonceGeneratorProvider).generate();
    final session = _Session(
      api: ref.read(restClientProvider),
      tokens: ref.read(tokenStoreProvider),
      repository: ref.read(authRepositoryProvider),
      entry: ref.read(entryStateProvider.notifier),
      draft: ref.read(onboardingDraftProvider.notifier),
      // 로그인이 실패해 기다리지 않게 돼도 읽기 오류가 미처리로 남지 않게 합니다.
      draftValue: ref.read(onboardingDraftProvider.future)..ignore(),
      // 마무리 의존성은 계정 id가 필요해 진입 계산 뒤에야 읽을 수 있습니다. 그때 이 controller가
      // 버려졌으면 읽지 않고, 저장은 onboard-call이 이어받습니다.
      readCompleter: () =>
          ref.mounted ? ref.read(onboardingCompleterProvider) : null,
      readMe: () => ref.mounted ? ref.read(meProvider) : null,
      rejectionNotice: ref.read(onboardingRejectionNoticeProvider.notifier),
      completing: ref.read(loginCompletingProvider.notifier),
      crashReporter: ref.read(crashReporterProvider),
    );
    try {
      final outcome = await login(rawNonce);
      if (outcome is LoginSucceeded) {
        final entryError = await session.enter(outcome.response, notice);
        if (entryError != null) {
          // 토큰은 저장됐지만 갈래를 몰라 화면이 넘어가지 않습니다. 안내하고 다시 시도를 받습니다.
          return LoginFailed(entryError);
        }
      }
      return outcome;
    } on SocialSignInCancelled {
      return const LoginCancelled();
    } on AppError catch (error) {
      return LoginFailed(error);
    } on Object catch (error, stack) {
      // 토큰 저장 실패·SDK 예외 등 통신 밖 실패도 화면이 안내할 수 있게 모읍니다. 진단을 위해
      // 요약(오류 타입)만 보고합니다(D64 ②: nonce·토큰·입력 값은 싣지 않음).
      session.crashReporter.record(CrashSummary.from(error), stack);
      return LoginFailed(UnexpectedError(error));
    }
  }
}

/// 로그인 뒤 진입에 쓰는 의존성 묶음입니다.
final class _Session {
  const new({
    required this.api,
    required this.tokens,
    required this.repository,
    required this.entry,
    required this.draft,
    required this.draftValue,
    required this.readCompleter,
    required this.readMe,
    required this.rejectionNotice,
    required this.completing,
    required this.crashReporter,
  });

  final DefaultApi api;
  final TokenStore tokens;
  final AuthRepository repository;
  final EntryController entry;
  final OnboardingDraftController draft;
  final Future<OnboardingDraft> draftValue;
  final OnboardingCompleter? Function() readCompleter;
  final Me? Function() readMe;
  final OnboardingRejectionNotice rejectionNotice;
  final LoginCompleting completing;
  final CrashReporter crashReporter;

  /// 토큰을 저장하고, 필요하면 입력을 쓰지 않는다는 안내 뒤 입력을 지우거나 입력을 프로필로
  /// 저장하고, 진입을 다시 계산합니다.
  ///
  /// 진입 계산이 실패하면 그 오류를, 아니면 null을 돌려줍니다.
  Future<AppError?> enter(
    LoginResponse response,
    DiscardNotice? discardNotice,
  ) async {
    // 이전 세션의 토큰(진입 계산 실패 뒤 다시 로그인한 경우)이 server에 남지 않게 먼저 폐기를 시도합니다.
    // 로컬 로그아웃 이벤트는 내지 않습니다. 곧 새 토큰이 덮어씁니다.
    await revokeStoredRefreshToken(
      api: api,
      tokens: tokens,
      recoverAuth: false,
    );
    await tokens.save(response.tokens);
    if (await _discardsDraft(response)) {
      await discardNotice?.call();
      try {
        await draft.clear();
      } on Object catch (error, stack) {
        // 지우지 못해도 로그인은 끝냅니다. 입력은 로그아웃 때 다시 지웁니다(D64 ②: 값은 싣지 않음).
        crashReporter.record(CrashSummary.from(error), stack);
      }
    }
    // 진입 계산이 profileRequired를 알리는 순간 라우터가 onboard-call로 보내므로, 입력을 저장할
    // 수 있는 로그인(동의함 + 입력 있음)은 끝날 때까지 login에 붙들어 둡니다(A79).
    final holds = await _mayCompleteProfile(response);
    if (holds) {
      completing.begin();
    }
    try {
      return await _refreshAndComplete();
    } finally {
      if (holds) {
        completing.end();
      }
    }
  }

  /// 진입을 계산하고, 동의했고 사주가 없는 계정이 미리보기 입력을 가졌으면 저장합니다(D90 ③).
  ///
  /// 내 정보는 진입 계산이 낸 값이라 계산 뒤에야 알 수 있습니다. 동의가 필요한 계정은 동의
  /// 화면이 저장을 맡습니다. 저장이 입력 오류(422)면 안내를 남기고, 그 밖의 실패와 입력이
  /// 모자란 경우는 진입을 다시 계산해 `onboard-call`에 맡깁니다.
  Future<AppError?> _refreshAndComplete() async {
    final entryError = await entry.refresh();
    if (entryError != null) {
      return entryError;
    }
    final me = readMe();
    if (me == null || me.consentRequired || me.hasProfile) {
      return null;
    }
    final completer = readCompleter();
    // 입력이 없으면 저장을 시도하지 않았으니 진입은 이미 최신입니다.
    if (completer == null || !await completer.isReady()) {
      return null;
    }
    if (await completer.completeIfReady(notice: rejectionNotice)) {
      return null;
    }
    return await entry.refresh();
  }

  /// 동의했고(로그인 응답) 온보딩 입력이 남아 있어 저장할 수도 있는 로그인이면 true.
  Future<bool> _mayCompleteProfile(LoginResponse response) async {
    if (response.consentRequired) {
      return false;
    }
    try {
      return await draftValue != const OnboardingDraft();
    } on Object {
      return false;
    }
  }

  /// 사주가 저장된 기존 계정이고 온보딩 입력이 남아 있으면 true.
  ///
  /// 새 계정은 약관 동의 뒤 입력으로 프로필을 만들고, 사주가 없는 기존 계정도 입력을 이어
  /// 쓰므로 남깁니다. 입력을 읽지 못하거나 계정 확인이 실패하면 입력을 남깁니다(진입 계산이
  /// 오류를 다룸).
  Future<bool> _discardsDraft(LoginResponse response) async {
    if (response.isNewAccount) {
      return false;
    }
    try {
      if (await draftValue == const OnboardingDraft()) {
        return false;
      }
      return await repository.hasProfile();
    } on Object {
      return false;
    }
  }
}

/// 로그인 화면 동작. 화면이 보이는 동안만 둡니다.
final AsyncNotifierProvider<LoginController, void> loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(
      LoginController.new,
    );
