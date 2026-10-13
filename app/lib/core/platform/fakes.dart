import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/app_check.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/core/platform/share.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';

/// 카카오 로그인 대역.
final class FakeKakaoAuth implements KakaoAuth {
  /// [failWith]를 주면 그 오류로 실패합니다.
  const new({this.failWith});

  /// 던질 오류. null이면 성공.
  final AppError? failWith;

  @override
  Future<KakaoCredential> signIn({required String nonce}) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    return const KakaoCredential(idToken: 'fake-kakao-id-token');
  }
}

/// Apple 로그인 대역.
final class FakeAppleAuth implements AppleAuth {
  /// [failWith]를 주면 그 오류로 실패합니다.
  const new({this.failWith, this.clientType = AppleClientType.native});

  /// 던질 오류. null이면 성공.
  final AppError? failWith;

  /// 돌려줄 로그인 흐름.
  final AppleClientType clientType;

  @override
  Future<AppleCredential> signIn({
    required String nonce,
    required String state,
  }) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    return AppleCredential(
      idToken: 'fake-apple-id-token',
      authorizationCode: 'fake-apple-authorization-code',
      clientType: clientType,
    );
  }
}

/// App Check 대역.
final class FakeAppCheck implements AppCheck {
  /// [tokenValue]를 항상 돌려줍니다.
  const new({this.tokenValue = 'fake-app-check-token'});

  /// 돌려줄 토큰.
  final String tokenValue;

  @override
  Future<String> token() async => tokenValue;
}

/// 푸시 대역. 사건은 [addOpen]·[addTokenRefresh]로 넣습니다.
final class FakePushMessaging implements PushMessaging {
  /// 권한 응답과 기기 토큰을 정합니다.
  new({this.permissionGranted = true, this.tokenValue = 'fake-push-token'});

  /// [requestPermission]의 응답.
  final bool permissionGranted;

  /// [token]의 응답.
  final String? tokenValue;

  final _opens = StreamController<PushOpen>.broadcast();
  final _refreshes = StreamController<String>.broadcast();

  /// 알림을 눌러 앱이 열린 사건을 넣습니다.
  void addOpen(PushOpen open) => _opens.add(open);

  /// 기기 토큰 갱신을 넣습니다.
  void addTokenRefresh(String token) => _refreshes.add(token);

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<PushOpen> get opens => _opens.stream;
}

/// 비정상 종료 보고 대역. 실제 구현과 같은 거름 규칙(D64 ②)을 씁니다.
final class FakeCrashReporter implements CrashReporter {
  /// 빈 기록으로 시작합니다.
  new();

  /// 보고된 오류.
  final errors = <Object>[];

  /// 남긴 breadcrumb(화면 id).
  final breadcrumbs = <String>[];

  /// 지금의 사용자 식별값.
  String? userId;

  @override
  void record(Object error, StackTrace stack) => errors.add(error);

  @override
  void setUser(String? accountId) {
    final sanitized = sanitizeAccountId(accountId);
    assert(
      accountId == null || sanitized != null,
      '계정 id(UUID)가 아닌 값은 보내지 않습니다(D64 ②).',
    );
    userId = sanitized;
  }

  @override
  void breadcrumb(String screenId) {
    final sanitized = sanitizeBreadcrumb(screenId);
    assert(sanitized != null, 'IA 화면 id가 아닌 breadcrumb입니다(D64 ②).');
    if (sanitized != null) {
      breadcrumbs.add(sanitized);
    }
  }
}

/// 광고 동의 대역.
final class FakeAdConsent implements AdConsent {
  /// 돌려줄 결과를 정합니다.
  const new({this.result = AdConsentResult.personalized});

  /// 돌려줄 결과.
  final AdConsentResult result;

  @override
  Future<AdConsentResult> gather() async => result;
}

/// 광고 대역.
final class FakeAds implements Ads {
  /// 광고별 준비 여부와 보상 여부를 정합니다.
  new({
    this.bannerAvailable = true,
    this.rewardedAvailable = true,
    this.rewardEarned = true,
  });

  /// false면 [loadBanner]가 null.
  final bool bannerAvailable;

  /// false면 [loadRewarded]가 null.
  final bool rewardedAvailable;

  /// [RewardedAdHandle.show]의 결과.
  final bool rewardEarned;

  /// [loadRewarded]에 넘어온 userId.
  final rewardedUserIds = <String>[];

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async =>
      bannerAvailable ? _FakeBannerAd(width: width) : null;

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) async {
    if (!rewardedAvailable) {
      return null;
    }
    rewardedUserIds.add(userId);
    return _FakeRewardedAd(earned: rewardEarned);
  }
}

final class _FakeBannerAd implements BannerAdHandle {
  new({required int width}) : size = Size(width.toDouble(), 50);

  @override
  final Size size;

  @override
  Widget get view => SizedBox.fromSize(size: size);

  @override
  void dispose() {}
}

final class _FakeRewardedAd implements RewardedAdHandle {
  const new({required this.earned});

  final bool earned;

  @override
  Future<bool> show() async => earned;
}

/// 인앱결제 대역.
final class FakePurchases implements Purchases {
  /// 상품과 구매 결과를 정합니다.
  new({
    this.catalog = const [
      StoreProduct(id: 'ad_free_1month', priceLabel: '₩2,500'),
    ],
    this.outcome = const PurchaseSucceeded(),
  });

  /// [products]의 응답.
  final List<StoreProduct> catalog;

  /// [buy]의 응답.
  final PurchaseOutcome outcome;

  /// 마지막으로 [logIn]한 계정 id.
  String? loggedInAccountId;

  @override
  Future<void> logIn(String accountId) async => loggedInAccountId = accountId;

  @override
  Future<List<StoreProduct>> products() async => catalog;

  @override
  Future<PurchaseOutcome> buy(String productId) async => outcome;
}

/// 공유 시트 대역. 공유 요청을 [shared]에 모읍니다.
final class FakeShareSheet implements ShareSheet {
  /// 빈 기록으로 시작합니다.
  new();

  /// 공유 요청 기록.
  final shared = <({Uint8List png, String text})>[];

  @override
  Future<void> sharePng(Uint8List png, {required String text}) async =>
      shared.add((png: png, text: text));
}
