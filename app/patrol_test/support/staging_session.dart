/// Patrol E2E의 staging 모드(#781, 결정 A108)입니다.
///
/// 앱은 http 모드로 staging server에 붙고, 로그인과 계정 준비만 Mac의 relay
/// (`tool/e2e_staging/relay.dart`, `adb reverse`로 같은 주소)를 거칩니다. relay만 staging 비밀을
/// 들고 있어 앱 빌드와 기기에는 비밀이 없습니다. `tool/patrol_staging.sh`가 relay를 띄우고
/// `--dart-define=E2E_MODE=staging`을 넘깁니다.
///
/// 단위 테스트(`test/patrol_support/`)가 읽을 수 있게 `package:patrol`을 import하지 않습니다.
library;

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderBase;
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/api/interceptors/auth.dart'
    show skipAuthExtra;
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/admob_ads.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/staging_ads.dart';
import 'package:myungli_diary/core/platform/unavailable_store.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

/// E2E 실행 모드입니다. [fake]는 대역 server, [staging]은 실제 staging server입니다.
enum E2eMode {
  /// 대역 server와 시나리오(기본, PR CI `e2e-android`).
  fake,

  /// staging server와 relay(`tool/patrol_staging.sh`).
  staging,
}

/// `--dart-define=E2E_MODE` 값입니다(`fake` 또는 `staging`, 없으면 `fake`).
const e2eModeName = String.fromEnvironment('E2E_MODE', defaultValue: 'fake');

/// [e2eModeName]으로 고른 모드입니다. 모르는 값은 [checkE2eModeName]이 막습니다.
const E2eMode e2eMode = e2eModeName == 'staging'
    ? E2eMode.staging
    : E2eMode.fake;

/// [e2eModeName]이 [E2eMode] 값 중 하나인지 봅니다. 아니면(오타 등) 조용히 fake로 돌지 않게
/// [StateError]입니다.
void checkE2eModeName() {
  if (!E2eMode.values.any((mode) => mode.name == e2eModeName)) {
    throw StateError('E2E_MODE는 fake 또는 staging이어야 합니다: $e2eModeName');
  }
}

/// relay 주소입니다. 에뮬레이터에서는 `adb reverse tcp:47283`으로 Mac의 relay에 닿습니다.
const relayBaseUrl = 'http://127.0.0.1:47283';

/// relay `/ready` 확인을 기다리는 시간입니다. 넘으면 relay가 없는 것으로 보고 바로 끝냅니다.
const _relayReadyTimeout = Duration(seconds: 3);

/// relay `/session`을 기다리는 시간입니다. relay가 staging을 여러 번 부르므로(로그인, 동의, 프로필,
/// 광고 제거 기간) relay의 요청당 시간보다 넉넉합니다.
const _relaySessionTimeout = Duration(seconds: 90);

const _labelAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// 테스트 계정 label을 만듭니다. `e2e` + [now]의 밀리초 시각 + 영숫자 4자(32자 이하)입니다.
///
/// relay는 `e2e`로 시작하는 label만 받아, 이 실행이 만든 계정만 지웁니다.
String newRelayLabel({DateTime? now, Random? random}) {
  final millis = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final picker = random ?? Random.secure();
  final suffix = String.fromCharCodes(
    List.generate(
      4,
      (_) => _labelAlphabet.codeUnitAt(picker.nextInt(_labelAlphabet.length)),
    ),
  );
  return 'e2e$millis$suffix';
}

/// 시나리오가 staging에서 앱을 띄우기 전에 준비할 계정 상태입니다.
sealed class StagingSetup {
  const new();
}

/// 계정을 만들지 않습니다. 로그인하면 화면의 로그인이 relay로 새 계정을 만듭니다.
final class NoSession extends StagingSetup {
  /// 계정 없음.
  const new();
}

/// 계정과 프로필만 만들고, 로그인은 화면에서 합니다(돌아온 사용자).
final class ExistingMember extends StagingSetup {
  /// 프로필이 있는 계정.
  const new();
}

/// 계정과 프로필을 만들고 로그인한 채로 띄웁니다.
final class SignedInMember extends StagingSetup {
  /// 로그인한 계정. [adFreeDays]일의 광고 제거 기간(근거 열림)을 줍니다.
  const new({this.adFreeDays = 0});

  /// 광고 제거 기간(일). 0이면 주지 않습니다.
  final int adFreeDays;
}

/// fake 시나리오 이름에 맞는 staging 준비입니다. 모르는 시나리오는 [ArgumentError]입니다.
StagingSetup stagingSetupFor(String scenario) => switch (scenario) {
  'new-user' || 'overseas' => const NoSession(),
  'returning-user' => const ExistingMember(),
  'member' || 'reward-unlock' => const SignedInMember(),
  'evidence-unlocked' => const SignedInMember(adFreeDays: 1),
  _ => throw ArgumentError.value(
    scenario,
    'scenario',
    'staging 준비가 정해지지 않은 시나리오입니다',
  ),
};

/// 소셜 로그인 요청(`POST /v1/auth/kakao|line|google|apple`)을 relay `POST /login`으로 돌립니다.
///
/// 기기에는 실제 제공자 토큰이 없으므로, relay가 staging 테스트 로그인(S24)을 [label]로 대신 부르고
/// 응답(LoginResponse)을 그대로 돌려줍니다. 토큰 갱신, 로그아웃, Apple 웹 흐름은 바꾸지 않습니다.
///
/// 돌린 요청에는 [skipAuthExtra]를 붙입니다. `/login`은 계약에 없는 경로라 인증 interceptor가
/// bearer가 필요한 요청으로 보고 refresh를 끼우거나 401을 세션 오류로 처리하지 않게 합니다.
final class RelayLoginInterceptor extends Interceptor {
  /// 로그인마다 [label]의 테스트 계정을 쓰는 interceptor를 만듭니다.
  new(this.label);

  /// 테스트 계정 label.
  final String label;

  static const _loginPaths = {
    '/v1/auth/kakao',
    '/v1/auth/line',
    '/v1/auth/google',
    '/v1/auth/apple',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' && _loginPaths.contains(options.path)) {
      options
        ..baseUrl = relayBaseUrl
        ..path = '/login'
        ..queryParameters = {}
        ..data = {'label': label}
        ..extra[skipAuthExtra] = true
        // 제공자 토큰과 App Check 헤더를 relay에 넘기지 않습니다.
        ..headers = {Headers.contentTypeHeader: Headers.jsonContentType};
    }
    handler.next(options);
  }
}

/// staging 모드에서 실제 adapter 대신 대역으로 채우는 provider입니다. [stagingReplacements]와 같은
/// 집합입니다.
final Set<ProviderBase<Object?>> stagingReplacedProviders = {
  kakaoAuthProvider,
  lineAuthProvider,
  googleAuthProvider,
  appleNativeAuthProvider,
  appleWebAuthProvider,
  pushMessagingProvider,
  purchasesProvider,
  adsProvider,
};

/// [stagingReplacedProviders]를 채우는 대역입니다.
///
/// * 로그인 SDK 다섯: 기본 대역. 대역이 낸 제공자 토큰은 [RelayLoginInterceptor]가 relay로 돌려 쓰지
///   않습니다.
/// * 푸시: 대역(에뮬레이터에 FCM 권한 창과 실제 등록을 만들지 않음).
/// * 결제: 상품 없는 대역(staging 결제는 이 테스트 범위 밖).
/// * 광고: 늘 모의 광고([StagingAds]의 실제 광고 자리에 [NoAds]). 보상형을 끝까지 보면 staging 보상
///   경로(S131)로 갑니다. Navigator와 배너 크기는 `realAds`와 같습니다.
final List<Override> stagingReplacements = [
  kakaoAuthProvider.overrideWith((ref) => FakeKakaoAuth()),
  lineAuthProvider.overrideWith((ref) => FakeLineAuth()),
  googleAuthProvider.overrideWith((ref) => FakeGoogleAuth()),
  appleNativeAuthProvider.overrideWith((ref) => FakeAppleNativeAuth()),
  appleWebAuthProvider.overrideWith((ref) => FakeAppleWebAuth()),
  pushMessagingProvider.overrideWith((ref) => FakePushMessaging()),
  purchasesProvider.overrideWith((ref) => FakePurchases(catalog: const [])),
  adsProvider.overrideWith(
    (ref) => StagingAds(
      real: const NoAds(),
      navigator: () =>
          ref.read(routerProvider).routerDelegate.navigatorKey.currentState,
      bannerSize: adMobAdaptiveBannerSize,
    ),
  ),
];

/// `dioProvider`를 감싸 [RelayLoginInterceptor]를 Dio 맨 앞에 둔 override입니다.
///
/// 앱과 같은 [createApiDio]로 Dio를 만들고 interceptor만 더하므로, 지켜보는 provider가 바뀌어 Dio가
/// 다시 만들어져도 새 Dio마다 interceptor가 들어갑니다. 맨 앞에 두어 뒤의 공통 헤더 interceptor가
/// relay 경로(`/login`)를 보고 App Check를 붙이지 않게 합니다.
Override relayDioOverride(String label) => dioProvider.overrideWith(
  (ref) =>
      createApiDio(ref)..interceptors.insert(0, RelayLoginInterceptor(label)),
);

/// 앱이 "오늘"로 쓰는 날짜입니다(`todayProvider`: `clockProvider`와 프로필 시간대 기준).
///
/// fake 모드는 시나리오 `today`, staging 모드는 staging을 도는 기기의 실제 오늘입니다. 흐름 테스트는
/// 날짜를 박지 말고 이 값에서 계산합니다.
CalendarDate e2eToday(ProviderContainer container) =>
    container.read(todayProvider);

/// [scenario]에 맞춰 staging 계정을 준비하고 http 모드로 앱 루트 container를 만듭니다.
///
/// relay를 먼저 확인하므로, relay가 없으면 앱 준비(Firebase, SDK 초기화)를 기다리지 않고
/// [StateError]('relay 준비 안 됨: ...')로 끝납니다. 로그인 요청은 이 실행의 새 label로 relay에
/// 갑니다([relayDioOverride]).
Future<ProviderContainer> bootstrapStaging({
  required String scenario,
  Locale? deviceLocale,
}) async {
  final setup = stagingSetupFor(scenario);
  final label = newRelayLabel();
  final relay = Dio(BaseOptions(baseUrl: relayBaseUrl));
  try {
    await expectRelayReady(relay);
    final container = await bootstrap(
      mode: ApiMode.http,
      deviceLocale: deviceLocale,
      // Patrol의 오류 처리를 지킵니다.
      installErrorHandlers: false,
      skipRealPlatform: stagingReplacedProviders,
      overrides: [...stagingReplacements, relayDioOverride(label)],
    );
    try {
      await _prepareAccount(container, relay, label: label, setup: setup);
    } on Object {
      container.dispose();
      rethrow;
    }
    return container;
  } finally {
    relay.close();
  }
}

/// relay `GET /ready`가 200인지 봅니다. 아니면 [StateError]입니다.
///
/// 메시지 끝에 원인을 붙입니다: 상태 코드(relay는 떠 있으나 응답이 200이 아님), `timeout`,
/// 또는 [DioExceptionType] 이름(`connectionError`면 relay나 `adb reverse`가 없음).
/// 비밀은 담지 않습니다.
@visibleForTesting
Future<void> expectRelayReady(
  Dio relay, {
  Duration timeout = _relayReadyTimeout,
}) async {
  String cause;
  try {
    final response = await relay
        .get<Object?>(
          '/ready',
          options: Options(sendTimeout: timeout, receiveTimeout: timeout),
        )
        .timeout(timeout);
    if (response.statusCode == 200) return;
    cause = 'status ${response.statusCode}';
  } on DioException catch (error) {
    final status = error.response?.statusCode;
    cause = status == null ? error.type.name : 'status $status';
  } on TimeoutException {
    cause = 'timeout';
  } on Object catch (error) {
    // 예상하지 못한 예외도 같은 메시지로 끝냅니다. 내용 대신 형식 이름만 남깁니다.
    cause = error.runtimeType.toString();
  }
  throw StateError('relay 준비 안 됨: tool/patrol_staging.sh로 실행 ($cause)');
}

/// [setup]대로 계정을 만들고, 로그인한 채로 띄울 때는 refresh token을 심습니다.
///
/// Android orchestrator가 테스트마다 앱 데이터를 지우므로, 진입 계산이 심은 토큰을 이전 설치의
/// 것으로 버리지 않게 설치 표시를 남깁니다(fake 모드 bootstrap과 같음).
Future<void> _prepareAccount(
  ProviderContainer container,
  Dio relay, {
  required String label,
  required StagingSetup setup,
}) async {
  await container
      .read(deviceFlagsStoreProvider)
      .writeBool(installedKey, value: true);
  final tokens = container.read(tokenStoreProvider);
  switch (setup) {
    case NoSession():
      await tokens.discardWithoutEvent();
    case ExistingMember():
      await _createSession(relay, label: label, adFreeDays: 0);
      await tokens.discardWithoutEvent();
    case SignedInMember(:final adFreeDays):
      final refreshToken = await _createSession(
        relay,
        label: label,
        adFreeDays: adFreeDays,
      );
      await tokens.seedRefreshToken(refreshToken);
  }
}

/// relay `POST /session`으로 프로필이 있는 [label] 계정을 만들고 refresh token을 돌려줍니다.
///
/// 실패하면 상태 코드만 담은 [StateError]입니다(응답 본문은 남기지 않음).
Future<String> _createSession(
  Dio relay, {
  required String label,
  required int adFreeDays,
}) async {
  final Response<Object?> response;
  try {
    response = await relay.post<Object?>(
      '/session',
      data: {'label': label, 'profile': true, 'adFreeDays': adFreeDays},
      options: Options(receiveTimeout: _relaySessionTimeout),
    );
  } on DioException catch (error) {
    throw StateError(
      'relay /session 실패: ${error.response?.statusCode ?? error.type.name}',
    );
  }
  final body = response.data;
  final refreshToken = body is Map ? body['refreshToken'] : null;
  if (refreshToken is! String) {
    throw StateError('relay /session 응답에 refreshToken이 없습니다');
  }
  return refreshToken;
}
