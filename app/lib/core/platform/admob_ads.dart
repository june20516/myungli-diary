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

/// 배너 요청이 이 시간 안에 답하지 않으면 실패로 봅니다(#1345).
///
/// prod 기기에서 SDK가 성공도 실패도 알리지 않아 배너가 불러오는 중에 멈춘 것을 봤습니다. 그
/// 원인(실행마다 동의 정보를 갱신하지 않음)은 [AdMobAds]가 고쳤고, 다른 이유로 같은 멈춤이 나도
/// 배너가 다시 시도하고 기록이 남도록 둡니다.
const adMobBannerTimeout = Duration(seconds: 30);

/// 시간 제한으로 끝난 배너 불러오기. SDK 오류와 겹치지 않게 앱 도메인을 씁니다.
const adMobBannerTimeoutFailure = AdMobLoadFailure(
  0,
  'no response',
  domain: 'app.timeout',
);

/// 보상형 광고를 닫은 뒤의 결과. [showError]가 있으면 보이지 못한 것입니다.
///
/// 보상을 받았으면 [adUnit]과 [rewardItem]을 결과에 담습니다(staging 보상 전달, D101 ④).
RewardedResult rewardedResultOf({
  required bool earned,
  Object? showError,
  String? adUnit,
  String? rewardItem,
}) {
  if (showError != null) return RewardFailed(UnexpectedError(showError));
  return earned
      ? RewardEarned(adUnit: adUnit, rewardItem: rewardItem)
      : const RewardDismissed();
}

/// SDK 경계가 던지는 불러오기 실패.
final class AdMobLoadFailure implements Exception {
  /// 실패를 담습니다.
  const new(this.code, this.message, {this.domain});

  /// SDK 오류 코드([adMobLoadError]).
  final int code;

  /// SDK 오류 메시지.
  final String message;

  /// SDK 오류 도메인(예 `com.google.android.gms.ads`). 없으면 null입니다.
  final String? domain;
}

/// AdMob SDK 경계. SDK 호출을 옮기기만 하고 분기는 [AdMobAds]에 둡니다.
abstract interface class AdMobApi {
  /// SDK를 초기화합니다.
  Future<void> initialize();

  /// 동의(UMP) 정보를 새로 받습니다. 동의 창은 띄우지 않습니다. 실패하면 던집니다.
  Future<void> requestConsentUpdate();

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

/// [width] 너비 일반 고정형 적응 배너의 크기(높이 50~90, 기기 높이의 15% 이하, A99).
/// 정하지 못하면 null입니다.
///
/// staging 모의 배너(D101 ③)가 실제 광고와 같은 크기를 쓰려고 함께 씁니다.
Future<Size?> adMobAdaptiveBannerSize(int width) async {
  final size = await _adaptiveSize(width);
  return size == null
      ? null
      : Size(size.width.toDouble(), size.height.toDouble());
}

/// 큰 고정형(높이 50~150, 기기 높이의 20% 이하)은 흔한 Android 폰에서 100dp를 넘어 탭 바와
/// 함께 화면 아래를 너무 가리므로 일반 고정형을 씁니다(F-033, #895).
Future<gma.AdSize?> _adaptiveSize(int width) =>
    // 플러그인 9.2는 이 함수에 큰 고정형으로 옮기라는 표시만 붙였고 일반 고정형의 다른
    // 함수는 없어, 표시를 알고 씁니다.
    // ignore: deprecated_member_use
    gma.AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

/// 실제 AdMob SDK를 부르는 경계(기본값).
final class SdkAdMobApi implements AdMobApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<void> initialize() => gma.MobileAds.instance.initialize();

  @override
  Future<void> requestConsentUpdate() {
    final done = Completer<void>();
    gma.ConsentInformation.instance.requestConsentInfoUpdate(
      gma.ConsentRequestParameters(),
      done.complete,
      (error) => done.completeError(StateError('UMP ${error.errorCode}')),
    );
    return done.future;
  }

  @override
  Future<bool> canRequestAds() =>
      gma.ConsentInformation.instance.canRequestAds();

  @override
  Future<BannerAdHandle?> loadBanner({
    required String unitId,
    required int width,
  }) async {
    final size = await _adaptiveSize(width);
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
          loaded.completeError(
            AdMobLoadFailure(error.code, error.message, domain: error.domain),
          );
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
            loaded.complete(_SdkRewarded(ad, unitId));
          },
          onAdFailedToLoad: (error) => loaded.completeError(
            AdMobLoadFailure(error.code, error.message, domain: error.domain),
          ),
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
  new(this._ad, this._unitId);

  final gma.RewardedAd _ad;
  final String _unitId;

  @override
  Future<RewardedResult> show() {
    final result = Completer<RewardedResult>();
    var earned = false;
    String? rewardItem;
    _ad.fullScreenContentCallback = gma.FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!result.isCompleted) {
          result.complete(
            rewardedResultOf(
              earned: earned,
              adUnit: _unitId,
              rewardItem: rewardItem,
            ),
          );
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
    unawaited(
      _ad.show(
        onUserEarnedReward: (_, reward) {
          earned = true;
          rewardItem = reward.type;
        },
      ),
    );
    return result.future;
  }
}

/// 광고의 실제 구현(AdMob, #686).
///
/// 실행마다 처음 부를 때 동의(UMP) 정보를 한 번 새로 받습니다. Google은 실행마다 갱신하라고
/// 하고, 갱신하지 않은 실행에서는 SDK가 광고 요청을 보내지 않고 성공도 실패도 알리지 않았습니다
/// (#1345). 갱신이 실패하면 그 실행에서는 다시 하지 않고 이전 실행의 동의 상태로 판단합니다.
/// 동의 창은 진입 흐름이 이 기기에서 처음 광고 전에 한 번 띄웁니다(`AdConsent.gather`).
///
/// SDK는 처음 부를 때 한 번 초기화하고, 실패하면 다음 호출에서 다시 초기화합니다. 동의
/// 상태(UMP)가 광고 요청을 허락하지 않거나 지원하지 않는 플랫폼이면 불러오지 않고 null입니다.
/// 불러오기 실패는 [adMobLoadError] 규칙으로 null이나 [AppError]가 됩니다. 배너가
/// [bannerTimeout] 안에 답하지 않으면 [adMobBannerTimeoutFailure]로 실패하고, 늦게 온 광고는 놓습니다.
final class AdMobAds implements Ads {
  /// adapter를 만듭니다.
  new({
    required this.platform,
    this.useTestAds = kDebugMode,
    this.api = const SdkAdMobApi(),
    this.onLoadFailure,
    this.bannerTimeout = adMobBannerTimeout,
  });

  /// 실행 플랫폼.
  final TargetPlatform platform;

  /// 테스트 광고 단위를 쓰는지(debug 빌드).
  final bool useTestAds;

  /// SDK 경계.
  final AdMobApi api;

  /// 불러오기 실패(채울 광고 없음 포함)를 알립니다. 원인(코드, 도메인)을 가리는 기록용입니다.
  final void Function(AdMobLoadFailure failure)? onLoadFailure;

  /// 배너 요청을 기다리는 최대 시간.
  final Duration bannerTimeout;

  Future<void>? _initialized;
  Future<void>? _consentUpdated;

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) => _load(
    AdMobFormat.banner,
    (unitId) => _bannerWithin(api.loadBanner(unitId: unitId, width: width)),
  );

  Future<BannerAdHandle?> _bannerWithin(Future<BannerAdHandle?> loading) =>
      loading.timeout(
        bannerTimeout,
        onTimeout: () {
          // 시간이 지난 뒤 온 광고는 보일 곳이 없어 놓고, 늦은 실패는 버립니다.
          unawaited(
            loading.then((late) => late?.dispose(), onError: (Object _) {}),
          );
          throw adMobBannerTimeoutFailure;
        },
      );

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) => _load(
    AdMobFormat.rewarded,
    (unitId) => api.loadRewarded(unitId: unitId, userId: userId),
  );

  Future<void> _updateConsent() async {
    try {
      await api.requestConsentUpdate();
    } on Object {
      // 갱신 실패는 이전 실행의 동의 상태로 판단합니다(아래 canRequestAds).
    }
  }

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
    await (_consentUpdated ??= _updateConsent());
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
      onLoadFailure?.call(failure);
      final error = adMobLoadError(failure.code, platform: platform);
      if (error == null) return null;
      throw error;
    }
  }
}
