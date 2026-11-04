import 'package:dio/dio.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:uuid/uuid.dart';

/// staging 보상 전달 경로(server S131, REST 계약 밖, build tag `staging`에만 있음).
const String stagingRewardPath = '/test/v1/billing/rewarded-ad';

/// staging 보상 전달(D101 ④). 시험은 이 경계를 대역으로 바꿉니다.
abstract interface class StagingRewardSender {
  /// [reward]를 보냅니다. 실패는 던집니다.
  Future<void> deliver(RewardEarned reward);
}

/// [StagingRewardSender]의 실제 구현(server S131 경로).
///
/// 보상형 광고를 끝까지 본 뒤 SSV와 같은 값(거래 id, 광고 단위, 보상 항목, 시각)을 staging 전용
/// 경로로 보냅니다. 인증은 로그인 계정 토큰이고(Dio의 bearer), 앱에 비밀 값은 없습니다. server는
/// 서명 검증만 건너뛰고 SSV와 같은 보상 처리로 근거 열람 권한을 부여합니다. 앱은 그 뒤 실제와
/// 같은 REST(`getEntitlements`)로 권한을 다시 읽습니다.
final class StagingRewardDelivery implements StagingRewardSender {
  /// [dio]로 보내고 시각은 [clock]에서 읽습니다.
  new(this.dio, {required this.clock, String Function()? newTransactionId})
    : _newTransactionId = newTransactionId ?? const Uuid().v4;

  /// 요청을 보내는 Dio(인증 interceptor 포함).
  final Dio dio;

  /// 시각.
  final Clock clock;

  final String Function() _newTransactionId;

  /// [reward]를 보냅니다. 실패는 Dio 오류 그대로 던집니다.
  @override
  Future<void> deliver(RewardEarned reward) async {
    await dio.post<Object?>(
      stagingRewardPath,
      data: <String, Object>{
        'transactionId': _newTransactionId(),
        'adUnit': ?reward.adUnit,
        'rewardItem': ?reward.rewardItem,
        'timestamp': clock.nowUtc().millisecondsSinceEpoch,
      },
    );
  }
}
