import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/account/data/account_link_repository.dart';
import 'package:myungli_diary/features/auth/application/provider_authenticator.dart';

/// IA `login-methods`의 출구 대상. 합치기 입구가 `account-merge`로 보냅니다.
const Set<String> loginMethodsExits = {ScreenIds.accountMerge};

/// IA `login-methods`가 직접 처리하는 상태. 붙이기·떼기 실패를 화면 안 안내로 그립니다.
const Set<String> loginMethodsHandledStates = {'error'};

/// 붙이기 시도 한 번의 결과입니다.
@immutable
sealed class LinkAttempt {
  const new();
}

/// 붙였고 목록이 갱신됐습니다.
final class LinkDone extends LinkAttempt {
  /// 성공.
  const new();
}

/// 붙이려는 인증 수단이 다른 계정에 연결돼 있어 연결하지 않았습니다(409
/// `auth.identity_in_use`·`auth.provider_taken`). 합치기로 넘어가지 않습니다(D85 ③).
final class LinkInUse extends LinkAttempt {
  /// 다른 계정에 연결됨.
  const new();
}

/// 취소, Apple 웹 실패, 증명 거절(401), 통신 실패 등으로 붙이지 못했습니다.
final class LinkFailed extends LinkAttempt {
  /// 실패.
  const new();
}

/// 떼기 시도 한 번의 결과입니다.
@immutable
sealed class UnlinkAttempt {
  const new();
}

/// 뗐거나(404 포함, 다른 기기에서 이미 뗌) 목록을 다시 읽었습니다.
final class UnlinkDone extends UnlinkAttempt {
  /// 성공.
  const new();
}

/// 떼지 못했습니다(마지막 수단 409, 통신 실패 등).
final class UnlinkFailed extends UnlinkAttempt {
  /// 실패.
  const new();
}

const _inUseCodes = {'auth.identity_in_use', 'auth.provider_taken'};
const _identityNotFound = 'auth.identity_not_found';

/// 로그인 수단 화면의 동작입니다(결정 A84, D85 ③). 상태는 연결된 제공자(붙인 순서)입니다.
///
/// 붙이기는 시도마다 새 원문 nonce로 인증해 증명을 server에 보냅니다. 떼기는 연결을 지우고
/// 목록을 다시 읽습니다. 어느 쪽도 제공자 쪽 허가를 취소하지 않습니다(D95). 붙이기·떼기 중에도
/// 목록 상태는 로딩으로 바뀌지 않고, 처리 중에 다시 부르면 새 요청 없이 진행 중인 시도의 결과를
/// 돌려줍니다(`LoginController`와 같은 규칙).
class LoginMethodsController extends AsyncNotifier<List<SocialProvider>> {
  @override
  Future<List<SocialProvider>> build() =>
      ref.read(accountLinkRepositoryProvider).methods();

  Future<LinkAttempt>? _linking;
  Future<UnlinkAttempt>? _unlinking;

  /// [provider]를 현재 계정에 붙입니다. 떼는 중이면 요청 없이 [LinkFailed]입니다.
  Future<LinkAttempt> link(SocialProvider provider) {
    final running = _linking;
    if (running != null) {
      return running;
    }
    if (_unlinking != null) {
      return Future.value(const LinkFailed());
    }
    return _linking = _link(provider).whenComplete(() => _linking = null);
  }

  /// [provider] 연결을 뗍니다. 붙이는 중이면 요청 없이 [UnlinkFailed]입니다.
  Future<UnlinkAttempt> unlink(SocialProvider provider) {
    final running = _unlinking;
    if (running != null) {
      return running;
    }
    if (_linking != null) {
      return Future.value(const UnlinkFailed());
    }
    return _unlinking = _unlink(provider).whenComplete(() => _unlinking = null);
  }

  /// 목록을 다시 읽습니다(합치기에서 돌아온 뒤). 로딩 없이 값만 바꾸고, 실패하면 이전 값을 둡니다.
  Future<void> refresh() async {
    final repository = ref.read(accountLinkRepositoryProvider);
    try {
      final methods = await repository.methods();
      if (ref.mounted) {
        state = AsyncData(methods);
      }
    } on AppError {
      // 이전 목록을 그대로 둡니다.
    }
  }

  Future<LinkAttempt> _link(SocialProvider provider) async {
    // 화면이 닫혀 이 controller가 버려져도 시작한 붙이기가 끝나도록 의존성을 먼저 잡아 둡니다.
    final authenticator = ref.read(providerAuthenticatorProvider);
    final repository = ref.read(accountLinkRepositoryProvider);
    final crashReporter = ref.read(crashReporterProvider);
    final rawNonce = ref.read(nonceGeneratorProvider).generate();
    try {
      final result = await authenticator.authenticate(
        provider,
        rawNonce: rawNonce,
      );
      switch (result) {
        case ProviderAppleWebFailed():
          return const LinkFailed();
        case ProviderAuthenticated(:final proof):
          final methods = await repository.link(proof);
          if (ref.mounted) {
            state = AsyncData(methods);
          }
          return const LinkDone();
      }
    } on SocialSignInCancelled {
      return const LinkFailed();
    } on ProblemError catch (error) {
      return _inUseCodes.contains(error.code)
          ? const LinkInUse()
          : const LinkFailed();
    } on AppError {
      return const LinkFailed();
    } on Object catch (error, stack) {
      // SDK 예외 등 통신 밖 실패도 화면이 안내할 수 있게 모읍니다(D64 ②: 요약만 보고).
      crashReporter.record(CrashSummary.from(error), stack);
      return const LinkFailed();
    }
  }

  Future<UnlinkAttempt> _unlink(SocialProvider provider) async {
    final repository = ref.read(accountLinkRepositoryProvider);
    try {
      try {
        await repository.unlink(provider);
      } on ProblemError catch (error) {
        // 다른 기기에서 이미 뗐으면 목록만 다시 읽습니다.
        if (error.code != _identityNotFound) {
          rethrow;
        }
      }
      final methods = await repository.methods();
      if (ref.mounted) {
        state = AsyncData(methods);
      }
      return const UnlinkDone();
    } on AppError {
      return const UnlinkFailed();
    }
  }
}

/// 로그인 수단 화면 동작. 화면이 보이는 동안만 둡니다.
final AsyncNotifierProvider<LoginMethodsController, List<SocialProvider>>
loginMethodsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      LoginMethodsController,
      List<SocialProvider>
    >(LoginMethodsController.new);
