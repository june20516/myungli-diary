import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/device_timezone.dart';
import 'package:myungli_diary/core/platform/external_browser.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/purchases.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/core/platform/push_channel.dart';
import 'package:myungli_diary/core/platform/share.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

// 기본값은 대역입니다. 실제 adapter는 계정 준비 뒤 override로 끼웁니다.
// App Check는 `appCheckProvider`(api_providers.dart)에 있습니다.

/// 로그인 제공자 설정(`config/auth.json`, A81). 테스트는 override로 값을 줍니다.
final authConfigProvider = Provider<AuthConfig>(
  (ref) => AuthConfig.fromEnvironment,
);

/// 카카오 로그인.
final kakaoAuthProvider = Provider<KakaoAuth>((ref) => FakeKakaoAuth());

/// LINE 로그인.
final lineAuthProvider = Provider<LineAuth>((ref) => FakeLineAuth());

/// Google 로그인.
final googleAuthProvider = Provider<GoogleAuth>((ref) => FakeGoogleAuth());

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

/// 알림 채널. 기본은 대역이고, http 모드 부팅이 실제 구현으로 바꿉니다(플러그인을
/// fake 모드와 테스트에서 부르지 않게).
final notificationChannelsProvider = Provider<NotificationChannels>(
  (ref) => FakeNotificationChannels(),
);

/// 비정상 종료 보고.
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => FakeCrashReporter(),
);

/// 광고 동의.
final adConsentProvider = Provider<AdConsent>((ref) => const FakeAdConsent());

/// 광고. fake 모드에서는 시나리오의 보상형 광고 결과(`rewardedAd`)대로 동작하는 대역입니다.
///
/// 시작 코드가 아니라 여기서 시나리오를 읽으므로 테스트는 이 provider를 직접 override할 수 있습니다.
final adsProvider = Provider<Ads>((ref) {
  if (ref.watch(apiModeProvider) != ApiMode.fake) {
    return FakeAds();
  }
  return fakeAdsFor(ref.watch(scenarioProvider).rewardedAd);
});

/// 인앱결제.
final purchasesProvider = Provider<Purchases>((ref) => FakePurchases());

/// OS 공유.
final shareSheetProvider = Provider<ShareSheet>((ref) => FakeShareSheet());

/// 기기 시간대. 기본은 대역이고, http 모드 부팅이 실제 adapter로, fake 모드가 시나리오 timezone으로 바꿉니다.
final deviceTimezoneProvider = Provider<DeviceTimezone>(
  (ref) => const FakeDeviceTimezone('Asia/Seoul'),
);

/// 기기 시간대의 IANA 이름. 앱이 뜨기 전에 한 번 읽어 두고(bootstrap), 다시 앞으로 올 때
/// invalidate해 다시 읽습니다. 다시 읽는 동안에도 이전 값이 남습니다.
final deviceTimezoneNameProvider = FutureProvider<String>(
  (ref) => ref.watch(deviceTimezoneProvider).current(),
);

/// 로그인 nonce·Apple 웹 `state` 생성기.
final nonceGeneratorProvider = Provider<NonceGenerator>(
  (ref) => NonceGenerator(),
);

/// 스토어 열기. 기본은 대역이고, http 모드 부팅이 실제 adapter로 바꿉니다.
final storeLauncherProvider = Provider<StoreLauncher>(
  (ref) => FakeStoreLauncher(),
);

/// 외부 브라우저 열기(약관·정책). 기본은 대역이고, http 모드 부팅이 실제 adapter로 바꿉니다.
final externalBrowserProvider = Provider<ExternalBrowser>(
  (ref) => FakeExternalBrowser(),
);
