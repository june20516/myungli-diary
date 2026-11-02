import 'package:myungli_diary/core/platform/ads.dart';

// 부팅이 AdMob adapter(결정 A99)를 끼우지 않은 http 모드(테스트 등)의 광고입니다. 대역처럼
// 가짜 성공을 만들지 않습니다.

/// 광고를 아직 쓸 수 없는 구현. 배너는 비고 보상형 버튼은 꺼집니다.
final class NoAds implements Ads {
  /// 구현을 만듭니다.
  const new();

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async => null;

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) async =>
      null;
}
