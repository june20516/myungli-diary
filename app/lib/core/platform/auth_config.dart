import 'package:flutter/foundation.dart';

/// 로그인 제공자의 공개 식별자(결정 A81).
///
/// 값은 비밀이 아니고 앱 바이너리에 그대로 들어갑니다. 출처는 `config/auth.json` 한 곳이고,
/// 실행·빌드 명령의 `--dart-define-from-file=config/auth.json`으로 들어옵니다. 값이 빈
/// 제공자는 adapter가 `ProviderNotConfigured`를 던집니다(버튼은 숨기지 않음).
@immutable
final class AuthConfig {
  /// 값을 직접 담습니다(테스트용). 앱은 [fromEnvironment]를 씁니다.
  const new({
    required this.kakaoNativeAppKey,
    required this.lineChannelId,
    required this.googleIosClientId,
    required this.googleServerClientId,
    required this.appleServicesId,
    required this.appleRedirectUri,
    required this.appLinkHost,
  });

  /// 빌드에 넘긴 `config/auth.json` 값. 넘기지 않았으면 모두 빈 값입니다.
  static const AuthConfig fromEnvironment = AuthConfig(
    kakaoNativeAppKey: String.fromEnvironment('KAKAO_NATIVE_APP_KEY'),
    lineChannelId: String.fromEnvironment('LINE_CHANNEL_ID'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    appleServicesId: String.fromEnvironment('APPLE_SERVICES_ID'),
    appleRedirectUri: String.fromEnvironment('APPLE_REDIRECT_URI'),
    appLinkHost: String.fromEnvironment('APP_LINK_HOST'),
  );

  /// 카카오 네이티브 앱 키.
  final String kakaoNativeAppKey;

  /// LINE 채널 id.
  final String lineChannelId;

  /// Google iOS client id. iOS만 씁니다.
  final String googleIosClientId;

  /// Google 웹 client id. server가 id_token `aud`로 확인하는 값입니다.
  final String googleServerClientId;

  /// Apple Services ID(Android 웹 흐름의 `client_id`).
  final String appleServicesId;

  /// Apple 웹 흐름의 server 콜백 전체 주소(`<API 주소>/v1/auth/apple/callback`).
  final String appleRedirectUri;

  /// App Link host(server `APP_LINK_BASE`의 host).
  final String appLinkHost;

  /// 카카오 로그인을 쓸 수 있는지.
  bool get isKakaoConfigured => _filled(kakaoNativeAppKey);

  /// LINE 로그인을 쓸 수 있는지.
  bool get isLineConfigured => _filled(lineChannelId);

  /// Google 로그인을 쓸 수 있는지. iOS([ios])면 iOS client id도 있어야 합니다.
  bool isGoogleConfigured({required bool ios}) =>
      _filled(googleServerClientId) && (!ios || _filled(googleIosClientId));

  /// Android Apple 웹 로그인을 쓸 수 있는지.
  bool get isAppleWebConfigured =>
      _filled(appleServicesId) &&
      _filled(appleRedirectUri) &&
      _filled(appLinkHost);

  static bool _filled(String value) => value.trim().isNotEmpty;
}
