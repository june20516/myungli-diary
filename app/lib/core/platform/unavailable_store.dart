import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/purchases.dart';

// http 모드에서 아직 실제 adapter가 없는 결제(RevenueCat, #684)와, 부팅이 AdMob
// adapter(결정 A99)를 끼우지 않은 http 모드(테스트 등)의 광고입니다. 대역처럼 가짜 성공을
// 만들지 않습니다.

/// 결제를 아직 쓸 수 없는 구현. 상품이 없고 사려 하면 실패로 끝납니다.
final class UnavailablePurchases implements Purchases {
  /// 구현을 만듭니다.
  const new();

  @override
  Future<void> logIn(String accountId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<void> sync() async {}

  @override
  Future<List<StoreProduct>> products() async => const [];

  @override
  Future<PurchaseOutcome> buy(String productId) async =>
      PurchaseFailed(UnexpectedError(StateError('결제를 아직 쓸 수 없습니다')));
}

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
