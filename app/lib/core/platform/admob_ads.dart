import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/ads.dart';

/// AdMob 광고 형식.
enum AdMobFormat {
  /// 탭 루트 하단 적응형 배너(D53 ①).
  banner,

  /// 근거 열람 보상형(D60 ③).
  rewarded,
}

/// [format]의 광고 단위 id(#686, 결정 A99).
///
/// [useTestAds](debug 빌드)면 Google 공식 테스트 단위입니다. 실제 단위로 개발 중 광고를
/// 누르면 계정 정지 사유라 빌드 모드로 가릅니다(D99와 같은 축). Android, iOS 밖은 null입니다.
String? adMobUnitId(
  AdMobFormat format, {
  required TargetPlatform platform,
  bool useTestAds = kDebugMode,
}) => switch ((platform, format, useTestAds)) {
  (TargetPlatform.android, AdMobFormat.banner, true) =>
    'ca-app-pub-3940256099942544/9214589741',
  (TargetPlatform.android, AdMobFormat.rewarded, true) =>
    'ca-app-pub-3940256099942544/5224354917',
  (TargetPlatform.iOS, AdMobFormat.banner, true) =>
    'ca-app-pub-3940256099942544/2435281174',
  (TargetPlatform.iOS, AdMobFormat.rewarded, true) =>
    'ca-app-pub-3940256099942544/1712485313',
  (TargetPlatform.android, AdMobFormat.banner, false) =>
    'ca-app-pub-5703509220233743/1453069424',
  (TargetPlatform.android, AdMobFormat.rewarded, false) =>
    'ca-app-pub-5703509220233743/5621087138',
  (TargetPlatform.iOS, AdMobFormat.banner, false) =>
    'ca-app-pub-5703509220233743/7635334395',
  (TargetPlatform.iOS, AdMobFormat.rewarded, false) =>
    'ca-app-pub-5703509220233743/8889414159',
  _ => null,
};

/// 광고 불러오기 실패 코드([code])의 앱 오류. 채울 광고가 없으면 null입니다.
///
/// 코드는 플랫폼마다 다릅니다: Android `AdRequest`는 2 네트워크, 3 광고 없음, iOS
/// `GADErrorCode`는 1 광고 없음, 2 네트워크입니다.
AppError? adMobLoadError(int code, {required TargetPlatform platform}) {
  final noFill = platform == TargetPlatform.iOS ? 1 : 3;
  if (code == noFill) return null;
  if (code == 2) return const OfflineError();
  return UnexpectedError(StateError('AdMob 불러오기 실패 $code'));
}

/// 보상형 광고를 닫은 뒤의 결과. [showError]가 있으면 보이지 못한 것입니다.
RewardedResult rewardedResultOf({required bool earned, Object? showError}) {
  if (showError != null) return RewardFailed(UnexpectedError(showError));
  return earned ? const RewardEarned() : const RewardDismissed();
}

/// SDK 경계가 던지는 불러오기 실패.
final class AdMobLoadFailure implements Exception {
  /// 실패를 담습니다.
  const new(this.code, this.message);

  /// SDK 오류 코드([adMobLoadError]).
  final int code;

  /// SDK 오류 메시지.
  final String message;
}

/// AdMob SDK 경계. SDK 호출을 옮기기만 하고 분기는 [AdMobAds]에 둡니다.
abstract interface class AdMobApi {
  /// SDK를 초기화합니다.
  Future<void> initialize();

  /// 동의(UMP) 상태가 광고 요청을 허락하는지.
  Future<bool> canRequestAds();

  /// [unitId]의 [width] 너비 적응형 배너. 크기를 정하지 못하면 null, 실패는
  /// [AdMobLoadFailure]입니다.
  Future<BannerAdHandle?> loadBanner({
    required String unitId,
    required int width,
  });

  /// [unitId]의 보상형 광고. SSV `userId`는 [userId]입니다. 실패는 [AdMobLoadFailure]입니다.
  Future<RewardedAdHandle?> loadRewarded({
    required String unitId,
    required String userId,
  });
}

/// 실제 AdMob SDK를 부르는 경계(기본값).
final class SdkAdMobApi implements AdMobApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<void> initialize() => gma.MobileAds.instance.initialize();

  @override
  Future<bool> canRequestAds() =>
      gma.ConsentInformation.instance.canRequestAds();

  @override
  Future<BannerAdHandle?> loadBanner({
    required String unitId,
    required int width,
  }) async {
    final size = await gma.AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return null;
    final loaded = Completer<BannerAdHandle>();
    await gma.BannerAd(
      adUnitId: unitId,
      size: size,
      request: const gma.AdRequest(),
      listener: gma.BannerAdListener(
        onAdLoaded: (ad) => loaded.complete(_SdkBanner(ad as gma.BannerAd)),
        onAdFailedToLoad: (ad, error) {
          unawaited(ad.dispose());
          loaded.completeError(AdMobLoadFailure(error.code, error.message));
        },
      ),
    ).load();
    return await loaded.future;
  }

  @override
  Future<RewardedAdHandle?> loadRewarded({
    required String unitId,
    required String userId,
  }) {
    final loaded = Completer<RewardedAdHandle>();
    unawaited(
      gma.RewardedAd.load(
        adUnitId: unitId,
        request: const gma.AdRequest(),
        rewardedAdLoadCallback: gma.RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            unawaited(
              ad.setServerSideOptions(
                gma.ServerSideVerificationOptions(userId: userId),
              ),
            );
            loaded.complete(_SdkRewarded(ad));
          },
          onAdFailedToLoad: (error) =>
              loaded.completeError(AdMobLoadFailure(error.code, error.message)),
        ),
      ),
    );
    return loaded.future;
  }
}

final class _SdkBanner implements BannerAdHandle {
  new(this._ad);

  final gma.BannerAd _ad;
  bool _disposed = false;

  @override
  Widget get view => gma.AdWidget(ad: _ad);

  @override
  Size get size => Size(_ad.size.width.toDouble(), _ad.size.height.toDouble());

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_ad.dispose());
  }
}

final class _SdkRewarded implements RewardedAdHandle {
  new(this._ad);

  final gma.RewardedAd _ad;

  @override
  Future<RewardedResult> show() {
    final result = Completer<RewardedResult>();
    var earned = false;
    _ad.fullScreenContentCallback = gma.FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!result.isCompleted) {
          result.complete(rewardedResultOf(earned: earned));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        unawaited(ad.dispose());
        if (!result.isCompleted) {
          result.complete(
            rewardedResultOf(earned: false, showError: error.message),
          );
        }
      },
    );
    unawaited(_ad.show(onUserEarnedReward: (_, _) => earned = true));
    return result.future;
  }
}

/// 광고의 실제 구현(AdMob, #686).
///
/// SDK는 처음 부를 때 한 번 초기화하고, 실패하면 다음 호출에서 다시 초기화합니다. 동의
/// 상태(UMP)가 광고 요청을 허락하지 않거나 지원하지 않는 플랫폼이면 불러오지 않고 null입니다.
/// 불러오기 실패는 [adMobLoadError] 규칙으로 null이나 [AppError]가 됩니다.
final class AdMobAds implements Ads {
  /// adapter를 만듭니다.
  new({
    required this.platform,
    this.useTestAds = kDebugMode,
    this.api = const SdkAdMobApi(),
  });

  /// 실행 플랫폼.
  final TargetPlatform platform;

  /// 테스트 광고 단위를 쓰는지(debug 빌드).
  final bool useTestAds;

  /// SDK 경계.
  final AdMobApi api;

  Future<void>? _initialized;

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) => _load(
    AdMobFormat.banner,
    (unitId) => api.loadBanner(unitId: unitId, width: width),
  );

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) => _load(
    AdMobFormat.rewarded,
    (unitId) => api.loadRewarded(unitId: unitId, userId: userId),
  );

  Future<T?> _load<T>(
    AdMobFormat format,
    Future<T?> Function(String unitId) load,
  ) async {
    final unitId = adMobUnitId(
      format,
      platform: platform,
      useTestAds: useTestAds,
    );
    if (unitId == null) return null;
    try {
      await (_initialized ??= api.initialize());
    } on Object catch (error) {
      _initialized = null;
      throw UnexpectedError(error);
    }
    if (!await api.canRequestAds()) return null;
    try {
      return await load(unitId);
    } on AdMobLoadFailure catch (failure) {
      final error = adMobLoadError(failure.code, platform: platform);
      if (error == null) return null;
      throw error;
    }
  }
}
