import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/app_error.dart';

/// 보상형 광고를 보인 결과.
sealed class RewardedResult {
  /// 하위 타입이 상속하는 기본 생성자입니다.
  const new();
}

/// 끝까지 봐서 보상을 받았습니다.
final class RewardEarned extends RewardedResult {
  /// 보상 받음.
  const new();
}

/// 보상 전에 닫았습니다.
final class RewardDismissed extends RewardedResult {
  /// 보상 전에 닫음.
  const new();
}

/// 광고를 표시하지 못했습니다.
final class RewardFailed extends RewardedResult {
  /// 실패 원인을 담습니다.
  const new(this.error);

  /// 실패 원인.
  final AppError error;
}

/// 불러온 배너 광고.
abstract interface class BannerAdHandle {
  /// 광고를 그리는 위젯.
  Widget get view;

  /// 광고 크기.
  Size get size;

  /// 광고를 해제합니다. 두 번 불러도 안전합니다.
  void dispose();
}

/// 불러온 보상형 광고.
abstract interface class RewardedAdHandle {
  /// 광고를 보이고 결과를 돌려줍니다.
  Future<RewardedResult> show();
}

/// 광고(AdMob).
abstract interface class Ads {
  /// [width] 너비의 적응형 배너를 불러옵니다. 준비되지 않았으면 null,
  /// 오류는 `AppError`로 던집니다.
  Future<BannerAdHandle?> loadBanner({required int width});

  /// 보상형 광고를 불러옵니다. [userId]는 SSV `userId`입니다. 준비되지 않았으면 null,
  /// 오류는 `AppError`로 던집니다.
  Future<RewardedAdHandle?> loadRewarded({required String userId});
}
