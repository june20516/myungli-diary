import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';

/// SDK 초기화 하나가 실패한 기록.
typedef AuthSdkFailure = ({Object error, StackTrace stack});

/// 카카오 SDK를 앱 키로 초기화합니다(기본값).
Future<void> kakaoSdkInit(String nativeAppKey) =>
    KakaoSdk.init(nativeAppKey: nativeAppKey);

/// LINE SDK를 채널 id로 준비합니다(기본값).
Future<void> lineSdkSetup(String channelId) =>
    LineSDK.instance.setup(channelId);

/// 설정([config])이 있는 로그인 SDK를 부팅 때 초기화합니다(spec §3 "끼우기").
///
/// 카카오는 `KakaoSdk.init`, LINE은 `LineSDK.setup`이고, Google은 첫 로그인 때 adapter가
/// 초기화합니다. 한 SDK가 실패해도 나머지는 초기화하고 실패를 모아 돌려줍니다. 앱 시작은
/// 막지 않습니다(그 제공자 로그인만 실패로 끝남).
Future<List<AuthSdkFailure>> initializeAuthSdks(
  AuthConfig config, {
  Future<void> Function(String nativeAppKey) initKakao = kakaoSdkInit,
  Future<void> Function(String channelId) setupLine = lineSdkSetup,
}) async {
  final failures = <AuthSdkFailure>[];
  Future<void> attempt(Future<void> Function() run) async {
    try {
      await run();
    } on Object catch (error, stack) {
      failures.add((error: error, stack: stack));
    }
  }

  if (config.isKakaoConfigured) {
    await attempt(() => initKakao(config.kakaoNativeAppKey.trim()));
  }
  if (config.isLineConfigured) {
    await attempt(() => setupLine(config.lineChannelId.trim()));
  }
  return failures;
}
