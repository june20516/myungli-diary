import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Sign in with Apple SDK 경계. SDK 호출을 그대로 옮기기만 하고 분기는
/// [SignInWithAppleNativeAuth]에 둡니다.
abstract interface class AppleIdCredentialApi {
  /// 이름·이메일 scope 없이 요청하고 identity token과 authorization code를 돌려줍니다.
  Future<({String? identityToken, String authorizationCode})> getCredential({
    required String nonce,
  });
}

/// 실제 Sign in with Apple SDK를 부르는 경계(기본값).
final class SdkAppleIdCredentialApi implements AppleIdCredentialApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<({String? identityToken, String authorizationCode})> getCredential({
    required String nonce,
  }) async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [],
      nonce: nonce,
    );
    return (
      identityToken: credential.identityToken,
      authorizationCode: credential.authorizationCode,
    );
  }
}

/// iOS Apple 로그인의 실제 구현(spec §5.3).
///
/// 설정은 필요 없고(Bundle ID와 entitlement만 씀), 제공자에게는 nonce 해시를 보냅니다.
/// Apple은 기기에 SDK 세션을 남기지 않아 정리할 것이 없습니다.
final class SignInWithAppleNativeAuth implements AppleNativeAuth {
  /// SDK 경계 [api]로 만듭니다.
  const new({this.api = const SdkAppleIdCredentialApi()});

  /// SDK 경계.
  final AppleIdCredentialApi api;

  @override
  Future<AppleNativeCredential> signIn({required String rawNonce}) async {
    final ({String? identityToken, String authorizationCode}) credential;
    try {
      credential = await api.getCredential(nonce: hashNonce(rawNonce));
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple 응답에 identity token이 없습니다');
    }
    return AppleNativeCredential(
      idToken: idToken,
      authorizationCode: credential.authorizationCode,
    );
  }
}
