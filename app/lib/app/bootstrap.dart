import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/app/auth_sdk_setup.dart';
import 'package:myungli_diary/app/depth_sheet_bodies.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/firebase_setup.dart';
import 'package:myungli_diary/app/licenses.dart';
import 'package:myungli_diary/app/profile_language.dart';
import 'package:myungli_diary/app/profile_timezone.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/platform/admob_ads.dart';
import 'package:myungli_diary/core/platform/apple_native_auth.dart';
import 'package:myungli_diary/core/platform/apple_web_auth.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/device_timezone.dart';
import 'package:myungli_diary/core/platform/external_browser.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/firebase_app_check.dart';
import 'package:myungli_diary/core/platform/firebase_crash_reporter.dart';
import 'package:myungli_diary/core/platform/firebase_push.dart';
import 'package:myungli_diary/core/platform/google_auth.dart';
import 'package:myungli_diary/core/platform/kakao_auth.dart';
import 'package:myungli_diary/core/platform/line_auth.dart';
import 'package:myungli_diary/core/platform/os_share.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/push_channel.dart';
import 'package:myungli_diary/core/platform/revenuecat_purchases.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';
import 'package:myungli_diary/core/platform/ump_ad_consent.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/purchase/application/purchase_providers.dart';

/// fake 모드에서 시나리오를 정하지 않았을 때 쓰는 시나리오.
const defaultScenarioId = 'new-user';

/// fake 모드가 쓰는 로컬 DB 파일 이름. 운영 DB와 분리합니다.
const fakeDatabaseName = 'myungli_diary_fake';

/// `--dart-define=SCENARIO=<id>`로 고르는 fake 모드 시작 시나리오.
const _scenarioFromEnvironment = String.fromEnvironment('SCENARIO');

var _licensesRegistered = false;

/// 앱이 뜨기 전에 필요한 준비를 하고 앱 루트 [ProviderContainer]를 돌려줍니다.
///
/// 시간대 데이터, 글꼴 라이선스, 비정상 종료 핸들러를 준비합니다. 로컬 DB는 provider가
/// 첫 쿼리 때 열고(마이그레이션 실패는 launch 화면의 오류 상태로 드러남) 여기서 열지
/// 않습니다. fake 모드에서는 [scenarioId](생략하면 `SCENARIO` dart-define, 그것도 없으면
/// [defaultScenarioId])의 시나리오와 대역 서버를 연결하고, 운영과 분리된 DB를 비워
/// 시나리오가 섞이지 않게 하며, 시나리오의 로그인 상태에 맞춰 토큰을 심거나 비웁니다.
/// 시계와 프로필 시간대는 시나리오 `today`의 현지 정오와 시나리오 timezone으로 바꿉니다.
/// 테스트는 [installErrorHandlers]를 꺼 테스트 틀의 오류 처리를 지킵니다.
/// [deviceLocale]을 주면 시나리오의 `locale`보다 먼저 쓰입니다.
///
/// 컨테이너를 만든 뒤의 준비가 실패하면 오류 요약을 보고하고 컨테이너를 닫은 뒤 다시 던집니다.
Future<ProviderContainer> bootstrap({
  ApiMode? mode,
  String? scenarioId,
  List<Override> overrides = const [],
  bool installErrorHandlers = true,
  Locale? deviceLocale,
}) async {
  final resolvedMode = mode ?? apiModeFromEnvironment();
  if (kReleaseMode && resolvedMode == ApiMode.fake) {
    throw StateError('release 빌드에서는 fake 모드를 쓸 수 없습니다.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZonesInitialized();
  if (!_licensesRegistered) {
    registerAppLicenses();
    _licensesRegistered = true;
  }

  final scenario = resolvedMode == ApiMode.fake
      ? await _pickScenario(scenarioId)
      : null;

  // 기기 로케일은 명시한 값, 없으면 시나리오의 값을 씁니다(둘 다 없으면 기기 값 그대로).
  final locale = deviceLocale ?? scenario?.locale;
  final container = ProviderContainer(
    overrides: [
      apiModeProvider.overrideWithValue(resolvedMode),
      if (locale != null) deviceLocaleProvider.overrideWithValue(locale),
      ...entryOverrides,
      ...profileTimezoneOverrides,
      ...profileLanguageOverrides,
      ...depthSheetBodyOverrides,
      ...daySheetBodyOverrides,
      ...realPlatformOverrides(resolvedMode),
      if (scenario != null) ...[
        databaseNameProvider.overrideWithValue(fakeDatabaseName),
        scenarioProvider.overrideWithValue(scenario),
        clockProvider.overrideWithValue(
          noonClockOn(scenario.today, scenario.timezone),
        ),
        deviceTimezoneProvider.overrideWithValue(
          FakeDeviceTimezone(scenario.timezone),
        ),
        fakeServerProvider.overrideWith(
          (ref) => ref.watch(fakeServerInterceptorProvider),
        ),
      ],
      ...overrides,
    ],
  );
  // 첫 프레임이 기본 시간대로 "오늘"을 계산하지 않게 기기 시간대를 먼저 읽어 둡니다.
  // 읽지 못하면(플러그인 오류) 기본 시간대로 시작합니다.
  try {
    await container.read(deviceTimezoneNameProvider.future);
  } on Object {
    // 기본 시간대로 계산합니다.
  }
  final reporter = container.read(crashReporterProvider);
  if (installErrorHandlers) {
    _installErrorHandlers(reporter);
  }
  if (resolvedMode == ApiMode.http) {
    // Firebase(A93)와 로그인 SDK는 실패해도 앱이 뜹니다. 그 기능만 실패로 끝나므로
    // 요약만 보고합니다(D64).
    final firebaseFailure = await initializeFirebase(
      env: firebaseEnvFromEnvironment(),
      platform: container.read(targetPlatformProvider),
    );
    if (firebaseFailure != null) {
      reporter.record(
        CrashSummary.from(firebaseFailure.error),
        firebaseFailure.stack,
      );
    }
    final failures = await initializeAuthSdks(
      container.read(authConfigProvider),
    );
    for (final failure in failures) {
      reporter.record(CrashSummary.from(failure.error), failure.stack);
    }
  }
  try {
    if (scenario != null) {
      await container.read(appDatabaseProvider).clearAll();
      // 비운 DB는 다시 설치한 것처럼 보이므로, 심을 토큰이 버려지지 않게 설치 표시를 남깁니다.
      await container
          .read(deviceFlagsStoreProvider)
          .writeBool(installedKey, value: true);
      await _restoreScenarioSession(container, scenario);
    }
  } on Object catch (error, stack) {
    reporter.record(CrashSummary.from(error), stack);
    container.dispose();
    rethrow;
  }
  return container;
}

/// 실제 platform adapter를 끼우는 override. fake 모드는 대역을 그대로 씁니다.
///
/// 로그인 adapter 다섯은 `config/auth.json`(A81) 값이 비면 로그인할 때
/// `ProviderNotConfigured`를 던집니다. http 모드에서 로그인 대역을 쓰지 않는 것은 가짜
/// 토큰을 실제 server에 보내지 않기 위해서입니다.
@visibleForTesting
List<Override> realPlatformOverrides(ApiMode mode) => switch (mode) {
  ApiMode.fake => const [],
  ApiMode.http => [
    appCheckProvider.overrideWithValue(const FirebaseAppCheckAdapter()),
    crashReporterProvider.overrideWithValue(const FirebaseCrashReporter()),
    pushMessagingProvider.overrideWithValue(const FirebasePushMessaging()),
    purchasesProvider.overrideWith(
      (ref) => RevenueCatPurchases(
        apiKey: revenueCatApiKey(platform: ref.watch(targetPlatformProvider)),
        productIds: ref.watch(adFreeProductIdsProvider),
      ),
    ),
    adConsentProvider.overrideWith(
      (ref) => UmpAdConsent(
        isIOS: ref.watch(targetPlatformProvider) == TargetPlatform.iOS,
      ),
    ),
    adsProvider.overrideWith(
      (ref) => AdMobAds(platform: ref.watch(targetPlatformProvider)),
    ),
    shareSheetProvider.overrideWithValue(const OsShareSheet()),
    notificationChannelsProvider.overrideWith(
      (ref) => LocalNotificationChannels(
        isAndroid: ref.watch(targetPlatformProvider) == TargetPlatform.android,
      ),
    ),
    deviceTimezoneProvider.overrideWithValue(const FlutterDeviceTimezone()),
    storeLauncherProvider.overrideWithValue(const UrlStoreLauncher()),
    externalBrowserProvider.overrideWithValue(const UrlExternalBrowser()),
    kakaoAuthProvider.overrideWith(
      (ref) => KakaoSdkAuth(config: ref.watch(authConfigProvider)),
    ),
    lineAuthProvider.overrideWith(
      (ref) => LineSdkAuth(config: ref.watch(authConfigProvider)),
    ),
    googleAuthProvider.overrideWith(
      (ref) => GoogleSdkAuth(
        config: ref.watch(authConfigProvider),
        isIos: ref.watch(targetPlatformProvider) == TargetPlatform.iOS,
        nonces: ref.watch(nonceGeneratorProvider),
      ),
    ),
    appleNativeAuthProvider.overrideWithValue(
      const SignInWithAppleNativeAuth(),
    ),
    appleWebAuthProvider.overrideWith(
      (ref) => WebAuthAppleWebAuth(
        config: ref.watch(authConfigProvider),
        nonces: ref.watch(nonceGeneratorProvider),
      ),
    ),
  ],
};

Future<Scenario> _pickScenario(String? requestedId) async {
  final id =
      requestedId ??
      (_scenarioFromEnvironment.isEmpty
          ? defaultScenarioId
          : _scenarioFromEnvironment);
  final scenarios = await loadScenarios(rootBundle);
  return scenarios.firstWhere(
    (scenario) => scenario.id == id,
    orElse: () => throw StateError(
      '없는 시나리오입니다: $id (있는 것: ${scenarios.map((s) => s.id).join(', ')})',
    ),
  );
}

/// 시나리오가 로그인 상태면 fixture의 refresh token을 심어, 앱을 다시 켠 것처럼
/// 세션 복원(refresh)이 일어나게 합니다. 아니면 토큰을 비웁니다.
Future<void> _restoreScenarioSession(
  ProviderContainer container,
  Scenario scenario,
) async {
  final tokens = container.read(tokenStoreProvider);
  if (!scenario.signedIn) {
    await tokens.discardWithoutEvent();
    return;
  }
  final server = container.read(fakeServerInterceptorProvider);
  final found = server is FakeServerInterceptor
      ? await server.findFixtureSource(const ['refreshToken.json'])
      : null;
  final json = found == null ? null : jsonDecode(found.source);
  final body = json is Map<String, Object?> ? json['body'] : null;
  final refreshToken = body is Map<String, Object?>
      ? body['refreshToken']
      : null;
  if (refreshToken is! String) {
    throw StateError('${scenario.id} 시나리오에 refreshToken fixture가 없습니다.');
  }
  await tokens.seedRefreshToken(refreshToken);
}

/// 처리되지 않은 오류를 [CrashReporter]에 요약만 보냅니다(원본 오류는 넘기지 않음, D64).
///
/// debug에서는 개발자가 볼 수 있게 콘솔에도 원본을 출력합니다.
void _installErrorHandlers(CrashReporter reporter) {
  FlutterError.onError = (details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    reporter.record(
      CrashSummary.from(details.exception),
      details.stack ?? StackTrace.empty,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('$error\n$stack');
    }
    reporter.record(CrashSummary.from(error), stack);
    return true;
  };
}
