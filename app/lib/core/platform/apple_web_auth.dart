import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:myungli_diary/core/platform/apple_web_return.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

/// 브라우저로 [url]을 열고 https App Link([httpsHost]·[httpsPath]) 복귀 주소를 돌려주는
/// 경계입니다. 기본값은 [flutterWebAuth2]입니다.
typedef WebAuthenticate = Future<String> Function({
  required Uri url,
  required String httpsHost,
  required String httpsPath,
});

/// `flutter_web_auth_2`로 여는 기본 경계(Android Auth Tab, 지원하지 않으면 Custom Tabs).
Future<String> flutterWebAuth2({
  required Uri url,
  required String httpsHost,
  required String httpsPath,
}) => FlutterWebAuth2.authenticate(
  url: url.toString(),
  callbackUrlScheme: 'https',
  options: FlutterWebAuth2Options(httpsHost: httpsHost, httpsPath: httpsPath),
);

/// Android Apple 웹 로그인의 실제 구현(spec §5.5, 결정 A80).
///
/// `state`를 새로 만들어 authorize URL(Services ID, server 콜백 `redirect_uri`,
/// nonce 해시)을 열고, App Link `/auth/apple`(또는 안내 페이지 intent)로 돌아온 주소를
/// [parseAppleWebReturn]으로 해석합니다. 탭을 닫거나 콜백 없이 앱으로 돌아오면
/// `userCancelled`입니다.
final class WebAuthAppleWebAuth implements AppleWebAuth {
  /// [config]의 Apple 웹 설정 셋 중 하나라도 비면 [signIn]이
  /// [ProviderNotConfigured]를 던집니다.
  const new({
    required this.config,
    required this.nonces,
    this.authenticate = flutterWebAuth2,
  });

  /// 제공자 설정.
  final AuthConfig config;

  /// `state`를 만듭니다.
  final NonceGenerator nonces;

  /// 브라우저 경계.
  final WebAuthenticate authenticate;

  /// App Link 복귀 경로(server `APP_LINK_BASE` 아래, A80).
  static const String returnPath = '/auth/apple';

  /// `flutter_web_auth_2`의 사용자 취소 code.
  static const String _cancelled = 'CANCELED';

  @override
  Future<AppleWebResult> signIn({required String rawNonce}) async {
    if (!config.isAppleWebConfigured) {
      throw const ProviderNotConfigured(SocialProvider.apple);
    }
    final state = nonces.generate();
    final url = buildAppleAuthorizeUri(
      clientId: config.appleServicesId.trim(),
      redirectUri: Uri.parse(config.appleRedirectUri.trim()),
      hashedNonce: hashNonce(rawNonce),
      state: state,
    );
    final String returned;
    try {
      returned = await authenticate(
        url: url,
        httpsHost: config.appLinkHost.trim(),
        httpsPath: returnPath,
      );
    } on PlatformException catch (error) {
      if (error.code == _cancelled) {
        return const AppleWebFailure(AppleWebError.userCancelled);
      }
      rethrow;
    }
    return parseAppleWebReturn(Uri.parse(returned), expectedState: state);
  }
}
