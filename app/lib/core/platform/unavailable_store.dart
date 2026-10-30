import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/purchases.dart';

// http 모드에서 아직 실제 adapter가 없는 결제와 광고입니다. RevenueCat(E12, #632)과
// AdMob(E13, #539) 값이 오면 실제 adapter로 바꿉니다. 대역처럼 가짜 성공을 만들지 않습니다.

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

/// 광고 동의를 묻지 않고 비맞춤으로 두는 구현. 광고가 없으니 묻지 않습니다.
final class NonPersonalizedAdConsent implements AdConsent {
  /// 구현을 만듭니다.
  const new();

  @override
  Future<AdConsentResult> gather() async => AdConsentResult.nonPersonalized;
}
