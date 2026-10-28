import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

/// 카카오 SDK 경계. SDK 호출을 그대로 옮기기만 하고 분기는 [KakaoSdkAuth]에 둡니다.
abstract interface class KakaoLoginApi {
  /// 카카오톡이 설치돼 있는지.
  Future<bool> isKakaoTalkInstalled();

  /// 카카오톡으로 로그인하고 `OAuthToken.idToken`을 돌려줍니다.
  Future<String?> loginWithKakaoTalk({required String nonce});

  /// 카카오 계정(브라우저)으로 로그인하고 `OAuthToken.idToken`을 돌려줍니다.
  Future<String?> loginWithKakaoAccount({required String nonce});

  /// SDK가 저장한 카카오 토큰을 지웁니다.
  Future<void> clearTokens();
}

/// 실제 카카오 SDK를 부르는 경계(기본값).
final class SdkKakaoLoginApi implements KakaoLoginApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<bool> isKakaoTalkInstalled() => kakao.isKakaoTalkInstalled();

  @override
  Future<String?> loginWithKakaoTalk({required String nonce}) async =>
      (await kakao.UserApi.instance.loginWithKakaoTalk(nonce: nonce)).idToken;

  @override
  Future<String?> loginWithKakaoAccount({required String nonce}) async =>
      (await kakao.UserApi.instance.loginWithKakaoAccount(nonce: nonce))
          .idToken;

  @override
  Future<void> clearTokens() =>
      kakao.TokenManagerProvider.instance.manager.clear();
}

/// 카카오 로그인의 실제 구현(spec §5.1, 결정 A82).
///
/// 카카오톡이 있으면 카카오톡, 그 밖의 실패면 계정 로그인입니다. 사용자 취소는 계정 로그인으로
/// 넘어가지 않습니다. 제공자에게는 nonce 해시를 보냅니다. id_token을 받은 뒤 SDK 토큰을
/// 지우고, 지우기 실패는 로그인을 막지 않습니다.
final class KakaoSdkAuth implements KakaoAuth {
  /// [config]의 카카오 앱 키가 비면 [signIn]이 [ProviderNotConfigured]를 던집니다.
  const new({required this.config, this.api = const SdkKakaoLoginApi()});

  /// 제공자 설정.
  final AuthConfig config;

  /// SDK 경계.
  final KakaoLoginApi api;

  /// 카카오 SDK의 사용자 취소 code.
  static const String _cancelled = 'CANCELED';

  @override
  Future<KakaoCredential> signIn({required String rawNonce}) async {
    if (!config.isKakaoConfigured) {
      throw const ProviderNotConfigured(SocialProvider.kakao);
    }
    final nonce = hashNonce(rawNonce);
    final idToken = await _login(nonce);
    if (idToken == null) {
      throw StateError('카카오 응답에 id_token이 없습니다(OpenID Connect 설정 확인)');
    }
    await _clearSession();
    return KakaoCredential(idToken: idToken);
  }

  Future<String?> _login(String nonce) async {
    if (await api.isKakaoTalkInstalled()) {
      try {
        return await api.loginWithKakaoTalk(nonce: nonce);
      } on PlatformException catch (error) {
        if (error.code == _cancelled) throw const SocialSignInCancelled();
        // 카카오톡에 연결된 계정이 없는 등 그 밖의 실패는 계정 로그인으로 넘어갑니다.
      }
    }
    try {
      return await api.loginWithKakaoAccount(nonce: nonce);
    } on PlatformException catch (error) {
      if (error.code == _cancelled) throw const SocialSignInCancelled();
      rethrow;
    }
  }

  Future<void> _clearSession() async {
    try {
      await api.clearTokens();
    } on Object {
      // 세션 정리 실패는 로그인을 막지 않습니다(A82). 다음 로그인 때 다시 지웁니다.
    }
  }
}
