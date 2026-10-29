import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/ia/ia_ids.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/app_check.dart';
import 'package:myungli_diary/core/platform/apple_web_return.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/device_timezone.dart';
import 'package:myungli_diary/core/platform/external_browser.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/core/platform/share.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

/// 카카오 로그인 대역.
final class FakeKakaoAuth implements KakaoAuth {
  /// [failWith]를 주면 그 오류로 실패합니다(취소는 `SocialSignInCancelled`).
  new({this.failWith});

  /// 던질 오류(`AppError` 또는 `SocialSignInCancelled`). null이면 성공.
  final Exception? failWith;

  /// 제공자에게 보낸 nonce(해시) 기록.
  final providerNonces = <String>[];

  @override
  Future<KakaoCredential> signIn({required String rawNonce}) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    providerNonces.add(hashNonce(rawNonce));
    return const KakaoCredential(idToken: 'fake-kakao-id-token');
  }
}

/// LINE 로그인 대역.
final class FakeLineAuth implements LineAuth {
  /// [failWith]를 주면 그 오류로 실패합니다(취소는 `SocialSignInCancelled`).
  new({this.failWith});

  /// 던질 오류(`AppError` 또는 `SocialSignInCancelled`). null이면 성공.
  final Exception? failWith;

  /// 제공자에게 보낸 nonce(해시) 기록.
  final providerNonces = <String>[];

  @override
  Future<LineCredential> signIn({required String rawNonce}) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    providerNonces.add(hashNonce(rawNonce));
    return const LineCredential(idToken: 'fake-line-id-token');
  }
}

/// Google 로그인 대역.
final class FakeGoogleAuth implements GoogleAuth {
  /// [failWith]를 주면 그 오류로 실패합니다(취소는 `SocialSignInCancelled`).
  new({this.failWith});

  /// 던질 오류(`AppError` 또는 `SocialSignInCancelled`). null이면 성공.
  final Exception? failWith;

  /// 제공자에게 보낸 nonce(해시) 기록.
  final providerNonces = <String>[];

  @override
  Future<GoogleCredential> signIn({required String rawNonce}) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    providerNonces.add(hashNonce(rawNonce));
    return GoogleCredential(
      idToken: 'fake-google-id-token',
      rawNonce: rawNonce,
    );
  }
}

/// iOS Apple 로그인 대역.
final class FakeAppleNativeAuth implements AppleNativeAuth {
  /// [failWith]를 주면 그 오류로 실패합니다(취소는 `SocialSignInCancelled`).
  new({this.failWith});

  /// 던질 오류(`AppError` 또는 `SocialSignInCancelled`). null이면 성공.
  final Exception? failWith;

  /// 제공자에게 보낸 nonce(해시) 기록.
  final providerNonces = <String>[];

  @override
  Future<AppleNativeCredential> signIn({required String rawNonce}) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    providerNonces.add(hashNonce(rawNonce));
    return const AppleNativeCredential(
      idToken: 'fake-apple-id-token',
      authorizationCode: 'fake-apple-authorization-code',
    );
  }
}

/// Android Apple 웹 로그인 대역. 실제 adapter와 같은 authorize URL과 복귀 해석을 씁니다.
final class FakeAppleWebAuth implements AppleWebAuth {
  /// 복귀 query와 실패 주입을 정합니다.
  new({
    this.failWith,
    this.returnQuery = const {'exchange': fakeAppleExchangeCode},
    this.returnedState,
    NonceGenerator? generator,
  }) : _generator = generator ?? NonceGenerator();

  /// 대역이 기본으로 돌려주는 교환 코드(계약 형식 43자).
  static const fakeAppleExchangeCode =
      'fakeAppleExchangeCode0000000000000000000000';

  /// 던질 오류. null이면 복귀를 흉내 냅니다.
  final AppError? failWith;

  /// 복귀 query 중 `state`를 뺀 값(`exchange` 또는 `error`).
  final Map<String, String> returnQuery;

  /// 복귀에 실을 `state`. null이면 연 URL의 `state`를 그대로 돌려줍니다.
  final String? returnedState;

  final NonceGenerator _generator;

  /// 연 authorize URL 기록.
  final openedUris = <Uri>[];

  @override
  Future<AppleWebResult> signIn({required String rawNonce}) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    final state = _generator.generate();
    openedUris.add(
      buildAppleAuthorizeUri(
        clientId: 'fake.services.id',
        redirectUri: Uri.parse('https://fake.invalid/v1/auth/apple/callback'),
        hashedNonce: hashNonce(rawNonce),
        state: state,
      ),
    );
    final link = Uri.https('fake.invalid', '/auth/apple', {
      ...returnQuery,
      'state': returnedState ?? state,
    });
    return parseAppleWebReturn(link, expectedState: state);
  }
}

/// App Check 대역.
final class FakeAppCheck implements AppCheck {
  /// [tokenValue]를 항상 돌려줍니다.
  const new({this.tokenValue = 'fake-app-check-token'});

  /// 돌려줄 토큰.
  final String tokenValue;

  @override
  Future<String?> token() async => tokenValue;
}

/// 푸시 대역. 사건은 [addOpen]·[addTokenRefresh]로 넣습니다.
final class FakePushMessaging implements PushMessaging {
  /// 권한 응답과 기기 토큰을 정합니다.
  new({
    this.permissionGranted = true,
    this.tokenValue = 'fake-push-token',
    this.initial,
  });

  /// [initialOpen]의 응답. 앱이 꺼진 상태에서 알림으로 시작한 경우를 흉내 냅니다.
  final PushOpen? initial;

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
  Future<PushOpen?> initialOpen() async => initial;

  /// 스트림 컨트롤러를 닫습니다.
  Future<void> dispose() async {
    await _opens.close();
    await _refreshes.close();
  }

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
  final errors = <CrashSummary>[];

  /// 남긴 breadcrumb(화면 id).
  final breadcrumbs = <String>[];

  /// 지금의 사용자 식별값.
  String? userId;

  @override
  void record(CrashSummary summary, StackTrace stack) => errors.add(summary);

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
    final sanitized = sanitizeScreenId(screenId);
    assert(sanitized != null, 'IA 화면 id가 아닌 breadcrumb입니다(D64 ②).');
    if (sanitized != null) {
      breadcrumbs.add(sanitized);
    }
  }
}

/// 광고 동의 대역.
final class FakeAdConsent implements AdConsent {
  /// 돌려줄 결과를 정합니다.
  const new({
    this.result = AdConsentResult.personalized,
    this.simulateError = false,
  });

  /// 돌려줄 결과.
  final AdConsentResult result;

  /// true면 SDK 오류를 흉내 내며, 예외 없이 비맞춤으로 끝납니다.
  final bool simulateError;

  @override
  Future<AdConsentResult> gather() async =>
      simulateError ? AdConsentResult.nonPersonalized : result;
}

/// 시나리오의 보상형 광고 결과([ScenarioRewardedAd])대로 동작하는 광고 대역. 배너는 늘 준비됩니다.
Ads fakeAdsFor(ScenarioRewardedAd rewardedAd) => switch (rewardedAd) {
  ScenarioRewardedAd.earned => FakeAds(),
  ScenarioRewardedAd.dismissed => FakeAds(
    rewardedResult: const RewardDismissed(),
  ),
  ScenarioRewardedAd.unavailable => FakeAds(rewardedAvailable: false),
  ScenarioRewardedAd.failed => FakeAds(
    rewardedResult: RewardFailed(
      UnexpectedError(StateError('대역: 보상형 광고를 표시하지 못했습니다.')),
    ),
  ),
};

/// 광고 대역.
final class FakeAds implements Ads {
  /// 광고별 준비 여부와 보상 여부를 정합니다.
  new({
    this.bannerAvailable = true,
    this.rewardedAvailable = true,
    this.rewardedResult = const RewardEarned(),
    this.bannerFailWith,
    this.rewardedFailWith,
  });

  /// false면 [loadBanner]가 null.
  final bool bannerAvailable;

  /// false면 [loadRewarded]가 null.
  final bool rewardedAvailable;

  /// [RewardedAdHandle.show]의 결과.
  final RewardedResult rewardedResult;

  /// [loadBanner]가 던질 오류. null이면 던지지 않습니다.
  final AppError? bannerFailWith;

  /// [loadRewarded]가 던질 오류. null이면 던지지 않습니다.
  final AppError? rewardedFailWith;

  /// [loadRewarded]에 넘어온 userId.
  final rewardedUserIds = <String>[];

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async {
    final error = bannerFailWith;
    if (error != null) {
      throw error;
    }
    return bannerAvailable ? _FakeBannerAd(width: width) : null;
  }

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) async {
    final error = rewardedFailWith;
    if (error != null) {
      throw error;
    }
    if (!rewardedAvailable) {
      return null;
    }
    rewardedUserIds.add(userId);
    return _FakeRewardedAd(result: rewardedResult);
  }
}

final class _FakeBannerAd implements BannerAdHandle {
  new({required int width}) : size = Size(width.toDouble(), 50);

  @override
  final Size size;

  @override
  Widget get view => SizedBox.fromSize(size: size);

  /// 여러 번 불러도 안전합니다.
  @override
  void dispose() {}
}

final class _FakeRewardedAd implements RewardedAdHandle {
  const new({required this.result});

  final RewardedResult result;

  @override
  Future<RewardedResult> show() async => result;
}

/// 인앱결제 대역.
final class FakePurchases implements Purchases {
  /// 상품과 구매 결과를 정합니다.
  new({
    // 가격은 비공개 결정이라 대역은 통화 기호 없는 자리표시 값을 씁니다(D74, #180).
    this.catalog = const [
      StoreProduct(
        id: fakeAdFreeProductId,
        title: '광고 제거 1개월',
        priceLabel: '가격',
      ),
    ],
    this.outcomes = const [PurchaseSucceeded()],
    this.logInFailWith,
    this.syncFailWith,
    this.onSync,
  });

  /// [products]의 응답.
  final List<StoreProduct> catalog;

  /// [buy]의 호출마다 차례로 돌려줄 응답. 끝에 닿으면 마지막 값을 반복합니다.
  final List<PurchaseOutcome> outcomes;

  /// [logIn]이 던질 오류. null이면 던지지 않습니다.
  final AppError? logInFailWith;

  /// [sync]가 던질 오류. null이면 던지지 않습니다.
  final AppError? syncFailWith;

  /// [sync]가 불릴 때마다 실행하는 훅. 호출 순서를 확인하는 테스트가 씁니다.
  final void Function()? onSync;

  /// [sync]를 부른 횟수.
  int syncCalls = 0;

  /// [buy]를 부른 횟수.
  int buyCalls = 0;

  /// 마지막으로 [logIn]한 계정 id.
  String? loggedInAccountId;

  @override
  Future<void> logIn(String accountId) async {
    final error = logInFailWith;
    if (error != null) {
      throw error;
    }
    loggedInAccountId = accountId;
  }

  @override
  Future<void> logOut() async => loggedInAccountId = null;

  @override
  Future<void> sync() async {
    syncCalls++;
    onSync?.call();
    final error = syncFailWith;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<List<StoreProduct>> products() async => catalog;

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    final index = buyCalls < outcomes.length ? buyCalls : outcomes.length - 1;
    buyCalls++;
    return outcomes[index];
  }
}

/// 공유 시트 대역. 공유 요청을 [shared]에 모읍니다.
final class FakeShareSheet implements ShareSheet {
  /// 실패 주입 여부를 정합니다.
  new({this.failWith});

  /// [sharePng]가 던질 오류. null이면 던지지 않습니다.
  final AppError? failWith;

  /// 공유 요청 기록.
  final shared = <({Uint8List png, String text})>[];

  @override
  Future<void> sharePng(Uint8List png, {required String text}) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    shared.add((png: png, text: text));
  }
}

/// 기기 시간대 대역.
final class FakeDeviceTimezone implements DeviceTimezone {
  /// [value]를 항상 돌려줍니다.
  const new(this.value);

  /// 돌려줄 IANA 이름.
  final String value;

  @override
  Future<String> current() async => value;
}

/// 외부 브라우저 대역. 연 주소를 [opened]에 차례로 남깁니다.
final class FakeExternalBrowser implements ExternalBrowser {
  /// 연 주소(실패한 시도 포함).
  final List<Uri> opened = [];

  /// 있으면 열 때 이 오류를 던집니다(브라우저 없음 등).
  Exception? failure;

  @override
  Future<void> open(Uri uri) async {
    opened.add(uri);
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}

/// 스토어 열기 대역. 연 횟수를 [opened]에 셉니다.
final class FakeStoreLauncher implements StoreLauncher {
  /// 스토어를 연 횟수(실패한 시도 포함).
  int opened = 0;

  /// 있으면 열 때 이 오류를 던집니다(스토어 앱 없음 등).
  Exception? failure;

  @override
  Future<void> openStore() async {
    opened++;
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}
