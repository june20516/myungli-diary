import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/sign_out.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

/// `account-delete`의 계정 삭제(결정 A63). 상태는 지우는 중인지입니다.
///
/// * `deleteMe`(202, 계정이 삭제 대기가 됨) 뒤 [revokeAndSignOut]으로 로그아웃합니다. 삭제 대기
///   계정의 토큰도 `logout`에 쓸 수 있고, 로컬 로그아웃의 `signedOut` 이벤트로 정리·SDK 해제·진입
///   재계산이 돌아 라우터가 `welcome`으로 보냅니다. 알림 기기는 server가 계정 삭제와 함께 모두
///   비활성으로 바꾸므로 `deleteDevice`를 따로 부르지 않습니다(계약 draft.11).
/// * 진행 중에 다시 부르면 새로 보내지 않고 진행 중인 시도를 돌려줍니다(두 번 누르기, Review Focus 2).
/// * `deleteMe`가 실패하면 [AppError]를 던지고 로그인 상태 그대로입니다(화면이 오류 toast와 다시
///   시도). 예상 밖 오류는 요약만 crash 기록에 남기고(D64) [UnexpectedError]로 던집니다.
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
    try {
      await api.deleteMe();
    } on DioException catch (error) {
      throw appErrorFrom(error);
    } on Object catch (error, stack) {
      ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
      throw UnexpectedError(error);
    }
    // 계정은 이미 삭제 대기입니다. 로그아웃은 best-effort server 폐기 뒤 로컬에서 반드시 합니다.
    await revokeAndSignOut(api: api, tokens: tokens);
  }
}

/// `account-delete` 화면의 계정 삭제. 화면이 보이는 동안만 둡니다.
final NotifierProvider<AccountDeleteController, bool>
accountDeleteControllerProvider =
    NotifierProvider.autoDispose<AccountDeleteController, bool>(
      AccountDeleteController.new,
    );
