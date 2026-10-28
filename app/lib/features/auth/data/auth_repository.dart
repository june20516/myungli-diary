import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/apple_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/apple_web_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/google_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/kakao_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/line_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_response.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/auth/model/provider_proof.dart';

/// 소셜 로그인 server 요청입니다(D55, Issue #100·#114).
///
/// 모든 요청에 nonce **원문**을 보냅니다. 제공자에게 보내는 해시는 adapter가 만듭니다.
/// 실패는 [AppError]입니다: 401 `auth.provider_token_invalid`,
/// 401 `auth.exchange_invalid`(교환 코드 없음·만료·이미 씀·nonce 불일치),
/// 503 `auth.provider_unavailable`(재시도).
final class AuthRepository {
  /// [_api]로 요청합니다.
  const new(this._api);

  final DefaultApi _api;

  /// [proof]의 종류와 제공자에 맞는 operation으로 로그인합니다(결정 A84).
  ///
  /// 카카오·LINE·Google은 `loginKakao`·`loginLine`·`loginGoogle`, iOS Apple은
  /// `loginApple`, Android Apple 웹 흐름의 교환 코드는 `completeAppleWebLogin`입니다.
  /// 교환 코드는 2분 일회용이라 실패하면 같은 코드로 다시 보내지 않고 처음부터 다시 로그인합니다.
  Future<LoginResponse> login(ProviderProof proof) => switch (proof) {
    AppleWebExchangeProof() => _loginAppleWeb(proof),
    IdTokenProof(provider: SocialProvider.kakao) => _loginKakao(proof),
    IdTokenProof(provider: SocialProvider.line) => _loginLine(proof),
    IdTokenProof(provider: SocialProvider.google) => _loginGoogle(proof),
    IdTokenProof(provider: SocialProvider.apple) => _loginAppleNative(proof),
  };

  Future<LoginResponse> _loginKakao(IdTokenProof proof) => _send(
    () => _api.loginKakao(
      kakaoLoginRequest: KakaoLoginRequest(
        idToken: proof.idToken,
        nonce: proof.rawNonce,
      ),
    ),
  );

  Future<LoginResponse> _loginLine(IdTokenProof proof) => _send(
    () => _api.loginLine(
      lineLoginRequest: LineLoginRequest(
        idToken: proof.idToken,
        nonce: proof.rawNonce,
      ),
    ),
  );

  Future<LoginResponse> _loginGoogle(IdTokenProof proof) => _send(
    () => _api.loginGoogle(
      googleLoginRequest: GoogleLoginRequest(
        idToken: proof.idToken,
        nonce: proof.rawNonce,
      ),
    ),
  );

  Future<LoginResponse> _loginAppleNative(IdTokenProof proof) async {
    final authorizationCode = proof.authorizationCode;
    if (authorizationCode == null) {
      throw UnexpectedError(StateError('Apple 증명에 authorization code가 없습니다.'));
    }
    return await _send(
      () => _api.loginApple(
        appleLoginRequest: AppleLoginRequest(
          idToken: proof.idToken,
          authorizationCode: authorizationCode,
          nonce: proof.rawNonce,
        ),
      ),
    );
  }

  Future<LoginResponse> _loginAppleWeb(AppleWebExchangeProof proof) => _send(
    () => _api.completeAppleWebLogin(
      appleWebLoginRequest: AppleWebLoginRequest(
        exchangeCode: proof.exchangeCode,
        nonce: proof.rawNonce,
      ),
    ),
  );

  /// 로그인한 계정에 사주 프로필이 저장돼 있는지(`getMe`의 `hasProfile`).
  Future<bool> hasProfile() async => (await _send(_api.getMe)).hasProfile;

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final data = (await request()).data;
      if (data == null) {
        throw UnexpectedError(StateError('빈 응답'));
      }
      return data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}
