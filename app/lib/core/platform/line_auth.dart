import 'package:flutter/services.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

/// LINE SDK 경계. SDK 호출을 그대로 옮기기만 하고 분기는 [LineSdkAuth]에 둡니다.
abstract interface class LineLoginApi {
  /// `openid` scope 하나로 로그인하고 `accessToken.idTokenRaw`를 돌려줍니다.
  Future<String?> login({required String nonce});

  /// SDK 세션을 지웁니다.
  Future<void> logout();
}

/// 실제 LINE SDK를 부르는 경계(기본값). 이메일·프로필 scope는 받지 않습니다(D82 ④).
final class SdkLineLoginApi implements LineLoginApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<String?> login({required String nonce}) async {
    final result = await LineSDK.instance.login(
      scopes: const ['openid'],
      option: LoginOption(false, 'normal')..idTokenNonce = nonce,
    );
    return result.accessToken.idTokenRaw;
  }

  @override
  Future<void> logout() => LineSDK.instance.logout();
}

/// LINE 로그인의 실제 구현(spec §5.2, 결정 A82·A83).
///
/// 제공자에게는 nonce 해시를 보냅니다. id_token을 받은 뒤 SDK 세션을 지우고, 지우기 실패는
/// 로그인을 막지 않습니다. `LineSDK.setup`은 부팅이 부릅니다.
final class LineSdkAuth implements LineAuth {
  /// [config]의 LINE 채널 id가 비면 [signIn]이 [ProviderNotConfigured]를 던집니다.
  const new({required this.config, this.api = const SdkLineLoginApi()});

  /// 제공자 설정.
  final AuthConfig config;

  /// SDK 경계.
  final LineLoginApi api;

  /// LINE SDK의 사용자 취소 code.
  static const String _cancelled = 'CANCEL';

  @override
  Future<LineCredential> signIn({required String rawNonce}) async {
    if (!config.isLineConfigured) {
      throw const ProviderNotConfigured(SocialProvider.line);
    }
    final String? idToken;
    try {
      idToken = await api.login(nonce: hashNonce(rawNonce));
    } on PlatformException catch (error) {
      if (error.code == _cancelled) throw const SocialSignInCancelled();
      rethrow;
    }
    if (idToken == null) {
      throw StateError('LINE 응답에 id_token이 없습니다(OpenID Connect 설정 확인)');
    }
    try {
      await api.logout();
    } on Object {
      // 세션 정리 실패는 로그인을 막지 않습니다(A82).
    }
    return LineCredential(idToken: idToken);
  }
}
