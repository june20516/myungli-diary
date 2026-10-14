import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/apple_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/apple_web_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/kakao_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_response.dart';

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

  /// 카카오 OIDC [idToken]으로 로그인합니다(`loginKakao`).
  Future<LoginResponse> kakao({
    required String idToken,
    required String rawNonce,
  }) => _send(
    () => _api.loginKakao(
      kakaoLoginRequest: KakaoLoginRequest(idToken: idToken, nonce: rawNonce),
    ),
  );

  /// iOS 네이티브 Apple 자격으로 로그인합니다(`loginApple`).
  Future<LoginResponse> appleNative({
    required String idToken,
    required String authorizationCode,
    required String rawNonce,
  }) => _send(
    () => _api.loginApple(
      appleLoginRequest: AppleLoginRequest(
        idToken: idToken,
        authorizationCode: authorizationCode,
        nonce: rawNonce,
      ),
    ),
  );

  /// Android Apple 웹 흐름의 교환 코드로 로그인합니다(`completeAppleWebLogin`).
  ///
  /// [exchangeCode]는 2분 일회용입니다. 실패하면 같은 코드로 다시 보내지 않고 처음부터
  /// 다시 로그인합니다.
  Future<LoginResponse> appleWeb({
    required String exchangeCode,
    required String rawNonce,
  }) => _send(
    () => _api.completeAppleWebLogin(
      appleWebLoginRequest: AppleWebLoginRequest(
        exchangeCode: exchangeCode,
        nonce: rawNonce,
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
