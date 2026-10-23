import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

/// `account-delete`의 계정 삭제(결정 A73, A63 대체). 상태는 지우는 중인지입니다.
///
/// * `deleteMe`가 204면 계정이 즉시 지워진 것입니다. 토큰이 모두 폐기돼 server `logout`을 부르지
///   않고 [TokenStore.signOut]으로 로컬 로그아웃만 합니다. 그 `signedOut` 이벤트로 정리·SDK 해제·
///   진입 재계산이 돌아 라우터가 `welcome`으로 보냅니다. 알림 기기는 server가 계정 삭제와 함께
///   모두 비활성으로 바꾸므로 `deleteDevice`를 따로 부르지 않습니다.
/// * 401이면 이미 지워진 것으로 보고 로컬 로그아웃합니다. interceptor가 먼저 로그아웃했을 수
///   있어 세션이 남아 있을 때만 합니다.
/// * 진행 중에 다시 부르면 새로 보내지 않고 진행 중인 시도를 돌려줍니다(두 번 누르기, Review Focus 2).
/// * 그 밖에 `deleteMe`가 실패하면 [AppError]를 던지고 로그인 상태 그대로입니다(화면이 오류 toast와
///   다시 시도). 예상 밖 오류(로컬 로그아웃 실패 포함)는 요약만 crash 기록에 남기고(D64)
///   [UnexpectedError]로 던집니다.
class AccountDeleteController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void>? _inFlight;

  /// 계정을 지우고 로그아웃합니다.
  Future<void> delete() {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    state = true;
    final attempt = _delete().whenComplete(() {
      _inFlight = null;
      if (ref.mounted) {
        state = false;
      }
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<void> _delete() async {
    final api = ref.read(restClientProvider);
    final tokens = ref.read(tokenStoreProvider);
    // 로컬 로그아웃(보안 저장소) 실패 등도 화면이 알릴 수 있게 감쌉니다(요약만 기록, D64).
    await guardUnexpected(ref.read(crashReporterProvider), () async {
      try {
        await api.deleteMe();
        await tokens.signOut();
      } on DioException catch (error) {
        final appError = appErrorFrom(error);
        if (!_isUnauthorized(appError)) {
          throw appError;
        }
        // 이미 지워진 계정입니다. refresh 거부로 interceptor가 먼저 로그아웃했을 수 있습니다.
        if (await tokens.hasSession()) {
          await tokens.signOut();
        }
      }
    });
  }

  bool _isUnauthorized(AppError error) => switch (error) {
    ProblemError(:final status) => status == 401,
    UnexpectedError(:final cause) =>
      cause is DioException && cause.response?.statusCode == 401,
    _ => false,
  };
}

/// `account-delete` 화면의 계정 삭제. 화면이 보이는 동안만 둡니다.
final NotifierProvider<AccountDeleteController, bool>
accountDeleteControllerProvider =
    NotifierProvider.autoDispose<AccountDeleteController, bool>(
      AccountDeleteController.new,
    );
