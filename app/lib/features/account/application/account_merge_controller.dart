import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/merge_preview.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/account/data/account_link_repository.dart';
import 'package:myungli_diary/features/auth/application/provider_authenticator.dart';
import 'package:uuid/uuid.dart';

/// IA `account-merge`의 출구 대상. 합치기가 끝나면 `login-methods`로 돌아갑니다.
const Set<String> accountMergeExits = {ScreenIds.loginMethods};

/// IA `account-merge`가 직접 처리하는 상태. 요약을 받는 동안 숨쉬기와 안내 창을 그립니다.
const Set<String> accountMergeHandledStates = {'loading', 'error'};

/// 409 `idempotency.in_progress` 뒤 다시 보내기 전 기다리는 시간.
const Duration mergeInProgressDelay = Duration(seconds: 1);

/// 409 `idempotency.in_progress` 뒤 다시 보내는 최대 횟수.
const int mergeInProgressRetries = 5;

/// [duration]만큼 기다립니다. 테스트가 시간을 건너뛰도록 바꿉니다.
typedef MergeRetryDelay = Future<void> Function(Duration duration);

/// 합치기 재전송 사이의 지연.
final mergeRetryDelayProvider = Provider<MergeRetryDelay>(
  (ref) => Future<void>.delayed,
);

/// 계정 합치기 화면의 단계입니다.
@immutable
sealed class AccountMergeState {
  const new();
}

/// 인증 단계. [busy]는 인증 중인 제공자이고 null이면 기다리는 중입니다.
final class MergeAuth extends AccountMergeState {
  /// 인증 단계.
  const new({this.busy});

  /// 인증 중인 제공자.
  final SocialProvider? busy;
}

/// 인증을 마치고 합칠 계정 요약을 받는 중입니다(IA `account-merge:loading`).
final class MergeSummaryLoading extends AccountMergeState {
  /// 요약 받는 중.
  const new();
}

/// 요약·고르기 단계. [selected]가 null이면 아직 고르지 않았습니다.
final class MergeChoosing extends AccountMergeState {
  /// 요약과 고른 프로필.
  const new(this.preview, {this.selected});

  /// 요약과 합치기 토큰. 토큰은 이 상태에만 둡니다(route·복원 상태에 두지 않음).
  final MergePreview preview;

  /// 남길 프로필.
  final MergeProfile? selected;
}

/// 합치는 중입니다. 고름과 뒤로 가기를 잠급니다.
final class MergeRunning extends AccountMergeState {
  /// 합치는 요약과 고른 프로필.
  const new(this.preview, this.selected);

  /// 요약과 합치기 토큰.
  final MergePreview preview;

  /// 남길 프로필.
  final MergeProfile selected;
}

/// 인증 한 번의 결과입니다.
@immutable
sealed class MergeAuthOutcome {
  const new();
}

/// 인증했고 요약을 받았습니다.
final class MergeAuthDone extends MergeAuthOutcome {
  /// 성공.
  const new();
}

/// [MergeNotOther]의 까닭.
enum MergeNotOtherReason {
  /// 인증한 인증 계정이 지금 유저 계정의 것(422 `merge.same_account`).
  self,

  /// 인증한 인증 계정이 어느 유저 계정에도 연결돼 있지 않음(422 `merge.no_account`).
  none,
}

/// 인증한 인증 계정으로는 합칠 다른 유저 계정이 없습니다. 연결로 넘어가지 않습니다(D85 ④).
final class MergeNotOther extends MergeAuthOutcome {
  /// 합칠 계정 없음.
  const new(this.reason);

  /// 까닭.
  final MergeNotOtherReason reason;
}

/// 증명 거절, Apple 웹 실패, 통신 실패 등으로 요약을 받지 못했습니다.
final class MergeAuthFailed extends MergeAuthOutcome {
  /// 실패.
  const new();
}

/// 사용자가 인증 창을 닫았습니다. 안내하지 않습니다.
final class MergeAuthCancelled extends MergeAuthOutcome {
  /// 취소.
  const new();
}

/// 합치기 한 번의 결과입니다.
@immutable
sealed class MergeOutcome {
  const new();
}

/// 합쳤고 캐시·초안을 지운 뒤 진입을 다시 계산했습니다.
final class MergeDone extends MergeOutcome {
  /// 성공.
  const new();
}

/// 합치기 토큰이 더는 쓸 수 없습니다(422 `merge.token_invalid`). 인증 단계로 돌아갔습니다.
final class MergeTokenInvalid extends MergeOutcome {
  /// 토큰 무효.
  const new();
}

/// 합치지 못했거나 결과를 모릅니다. 고름은 그대로입니다.
final class MergeFailed extends MergeOutcome {
  /// 실패.
  const new();
}

const _sameAccount = 'merge.same_account';
const _noAccount = 'merge.no_account';
const _tokenInvalid = 'merge.token_invalid';
const _inProgress = 'idempotency.in_progress';

/// 계정 합치기 화면의 동작입니다(D85 ④, spec §9).
///
/// 인증은 시도마다 새 원문 nonce로 하고 세션은 로그인처럼 바로 정리합니다. 그만두기는 화면을
/// 떠나 이 provider가 버려지며 합치기 토큰도 함께 버려지는 것이라 따로 동작이 없습니다.
/// 어느 갈래에서도 제공자 허가를 취소하지 않고(D95) 토큰 저장소를 바꾸지 않습니다.
///
/// `Idempotency-Key`는 (합치기 토큰, 프로필) 조합마다 하나입니다. 409 `idempotency.in_progress`는
/// [mergeInProgressDelay] 뒤 같은 키로 [mergeInProgressRetries]번까지, 응답 없음(연결 끊김·시간
/// 초과)은 같은 토큰·본문·키로 한 번 다시 보냅니다(S115).
///
/// 처리 중에 다시 부르면 새 요청 없이 진행 중인 시도의 결과를 돌려줍니다(`LoginMethodsController`와
/// 같은 규칙).
class AccountMergeController extends Notifier<AccountMergeState> {
  @override
  AccountMergeState build() => const MergeAuth();

  Future<MergeAuthOutcome>? _authenticating;
  Future<MergeOutcome>? _merging;

  /// 키를 만든 합치기 토큰. 토큰이 바뀌면 [_keys]를 비웁니다.
  String? _keyToken;
  final Map<MergeProfile, String> _keys = {};

  /// [provider]로 가져올 계정을 인증하고 요약을 받습니다. 인증 단계가 아니면 요청 없이 실패입니다.
  Future<MergeAuthOutcome> authenticate(SocialProvider provider) {
    final running = _authenticating;
    if (running != null) {
      return running;
    }
    final current = state;
    if (current is! MergeAuth) {
      return Future.value(const MergeAuthFailed());
    }
    state = MergeAuth(busy: provider);
    return _authenticating = _authenticate(provider)
        .whenComplete(() => _authenticating = null);
  }

  /// 남길 프로필을 고릅니다. 요약·고르기 단계에서만 바뀝니다.
  void choose(MergeProfile profile) {
    final current = state;
    if (current is MergeChoosing) {
      state = MergeChoosing(current.preview, selected: profile);
    }
  }

  /// 고른 프로필로 합칩니다. 고르기 전이면 요청 없이 [MergeFailed]입니다.
  Future<MergeOutcome> merge() {
    final running = _merging;
    if (running != null) {
      return running;
    }
    final current = state;
    if (current is! MergeChoosing) {
      return Future.value(const MergeFailed());
    }
    final selected = current.selected;
    if (selected == null) {
      return Future.value(const MergeFailed());
    }
    state = MergeRunning(current.preview, selected);
    return _merging = _merge(
      current.preview,
      selected,
    ).whenComplete(() => _merging = null);
  }

  Future<MergeAuthOutcome> _authenticate(SocialProvider provider) async {
    final authenticator = ref.read(providerAuthenticatorProvider);
    final repository = ref.read(accountLinkRepositoryProvider);
    final crashReporter = ref.read(crashReporterProvider);
    final rawNonce = ref.read(nonceGeneratorProvider).generate();
    MergeAuthOutcome backToAuth(MergeAuthOutcome outcome) {
      if (ref.mounted) {
        state = const MergeAuth();
      }
      return outcome;
    }

    try {
      final result = await authenticator.authenticate(
        provider,
        rawNonce: rawNonce,
      );
      switch (result) {
        case ProviderAppleWebFailed(:final error):
          return backToAuth(
            error == AppleWebError.userCancelled
                ? const MergeAuthCancelled()
                : const MergeAuthFailed(),
          );
        case ProviderAuthenticated(:final proof):
          if (ref.mounted) {
            state = const MergeSummaryLoading();
          }
          final preview = await repository.preview(proof);
          if (ref.mounted) {
            state = MergeChoosing(preview);
          }
          return const MergeAuthDone();
      }
    } on SocialSignInCancelled {
      return backToAuth(const MergeAuthCancelled());
    } on ProblemError catch (error) {
      return backToAuth(switch (error.code) {
        _sameAccount => const MergeNotOther(MergeNotOtherReason.self),
        _noAccount => const MergeNotOther(MergeNotOtherReason.none),
        _ => const MergeAuthFailed(),
      });
    } on AppError {
      return backToAuth(const MergeAuthFailed());
    } on Object catch (error, stack) {
      // SDK 예외 등 통신 밖 실패도 화면이 안내할 수 있게 모읍니다(D64 ②: 요약만 보고).
      crashReporter.record(CrashSummary.from(error), stack);
      return backToAuth(const MergeAuthFailed());
    }
  }

  /// (토큰, 프로필) 조합의 키. 같은 조합이면 같은 키를 다시 씁니다.
  String _keyFor(String token, MergeProfile profile) {
    if (_keyToken != token) {
      _keyToken = token;
      _keys.clear();
    }
    return _keys.putIfAbsent(profile, () => const Uuid().v4());
  }

  Future<MergeOutcome> _merge(
    MergePreview preview,
    MergeProfile selected,
  ) async {
    // 합치는 동안 화면을 떠날 수 없지만, 버려져도 끝맺도록 의존성을 먼저 잡아 둡니다.
    final repository = ref.read(accountLinkRepositoryProvider);
    final delay = ref.read(mergeRetryDelayProvider);
    final database = ref.read(appDatabaseProvider);
    final entry = ref.read(entryStateProvider.notifier);
    final crashReporter = ref.read(crashReporterProvider);
    final token = preview.mergeToken;
    final key = _keyFor(token, selected);
    var inProgressRetries = 0;
    var resentAfterNoResponse = false;
    try {
      while (true) {
        try {
          final me = await repository.merge(
            mergeToken: token,
            profile: selected,
            idempotencyKey: key,
          );
          await _guard(crashReporter, database.clearAccountData);
          final entryError = await entry.applyMe(me);
          if (entryError != null) {
            // 합쳐졌으므로 성공으로 둡니다. 갈래는 다음 진입 계산이 맞춥니다.
            recordUnlessAppError(crashReporter, entryError, StackTrace.current);
          }
          return const MergeDone();
        } on ProblemError catch (error) {
          if (error.code == _inProgress &&
              inProgressRetries < mergeInProgressRetries) {
            inProgressRetries++;
            await delay(mergeInProgressDelay);
            continue;
          }
          if (error.code == _tokenInvalid) {
            _backToAuth();
            return const MergeTokenInvalid();
          }
          rethrow;
        } on OfflineError {
          if (resentAfterNoResponse) rethrow;
          resentAfterNoResponse = true;
        } on TimeoutError {
          if (resentAfterNoResponse) rethrow;
          resentAfterNoResponse = true;
        }
      }
    } on AppError {
      return _keepChoice(preview, selected);
    } on Object catch (error, stack) {
      // 통신 밖 실패도 화면이 안내할 수 있게 모읍니다(D64 ②: 요약만 보고, 토큰은 싣지 않음).
      crashReporter.record(CrashSummary.from(error), stack);
      return _keepChoice(preview, selected);
    }
  }

  void _backToAuth() {
    _keyToken = null;
    _keys.clear();
    if (ref.mounted) {
      state = const MergeAuth();
    }
  }

  MergeOutcome _keepChoice(MergePreview preview, MergeProfile selected) {
    if (ref.mounted) {
      state = MergeChoosing(preview, selected: selected);
    }
    return const MergeFailed();
  }

  /// 정리 한 단계. 실패해도 합치기는 끝났으므로 요약만 보고하고 넘어갑니다.
  Future<void> _guard(
    CrashReporter crashReporter,
    Future<void> Function() step,
  ) async {
    try {
      await step();
    } on Object catch (error, stack) {
      crashReporter.record(CrashSummary.from(error), stack);
    }
  }
}

/// 계정 합치기 화면 동작. 화면이 보이는 동안만 두고, 떠나면 합치기 토큰과 함께 버립니다.
final NotifierProvider<AccountMergeController, AccountMergeState>
accountMergeControllerProvider =
    NotifierProvider.autoDispose<AccountMergeController, AccountMergeState>(
      AccountMergeController.new,
    );
