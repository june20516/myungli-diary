import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/device_timezone.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/core/platform/share.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

// 기본값은 대역입니다. 실제 adapter는 계정 준비 뒤 override로 끼웁니다.
// App Check는 `appCheckProvider`(api_providers.dart)에 있습니다.

/// 카카오 로그인.
final kakaoAuthProvider = Provider<KakaoAuth>((ref) => FakeKakaoAuth());

/// iOS Apple 로그인.
final appleNativeAuthProvider = Provider<AppleNativeAuth>(
  (ref) => FakeAppleNativeAuth(),
);

/// Android Apple 웹 로그인.
final appleWebAuthProvider = Provider<AppleWebAuth>(
  (ref) => FakeAppleWebAuth(),
);

/// 푸시 알림.
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FakePushMessaging(),
);

/// 비정상 종료 보고.
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => FakeCrashReporter(),
);

/// 광고 동의.
final adConsentProvider = Provider<AdConsent>((ref) => const FakeAdConsent());

/// 광고.
final adsProvider = Provider<Ads>((ref) => FakeAds());

/// 인앱결제.
final purchasesProvider = Provider<Purchases>((ref) => FakePurchases());

/// OS 공유.
final shareSheetProvider = Provider<ShareSheet>((ref) => FakeShareSheet());

/// 기기 시간대. fake 모드는 시나리오 timezone으로 바꿉니다(bootstrap).
final deviceTimezoneProvider = Provider<DeviceTimezone>(
  (ref) => const FlutterDeviceTimezone(),
);

/// 로그인 nonce·Apple 웹 `state` 생성기.
final nonceGeneratorProvider = Provider<NonceGenerator>(
  (ref) => NonceGenerator(),
);

/// 스토어 열기.
final storeLauncherProvider = Provider<StoreLauncher>(
  (ref) => const UrlStoreLauncher(),
);
