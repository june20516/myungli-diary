import 'package:flutter/widgets.dart';

/// 불러온 배너 광고.
abstract interface class BannerAdHandle {
  /// 광고를 그리는 위젯.
  Widget get view;

  /// 광고 크기.
  Size get size;

  /// 광고를 해제합니다.
  void dispose();
}

/// 불러온 보상형 광고.
abstract interface class RewardedAdHandle {
  /// 광고를 보입니다. 보상을 받았으면 true.
  Future<bool> show();
}

/// 광고(AdMob).
abstract interface class Ads {
  /// [width] 너비의 적응형 배너를 불러옵니다. 준비되지 않았으면 null.
  Future<BannerAdHandle?> loadBanner({required int width});

  /// 보상형 광고를 불러옵니다. [userId]는 SSV `userId`입니다. 준비되지 않았으면 null.
  Future<RewardedAdHandle?> loadRewarded({required String userId});
}
