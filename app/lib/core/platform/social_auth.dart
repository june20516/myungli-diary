// 소셜 로그인 인터페이스입니다(server 결정 S15·S22, 계약 1.0.0-draft.2).
// 모든 adapter는 nonce 원문을 받아 제공자에게는 `hashNonce(원문)`을 보냅니다.
// 원문은 호출한 쪽이 server(`loginKakao`·`loginApple`·`completeAppleWebLogin`)에 보냅니다.

import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

/// 사용자가 제공자 로그인 창을 닫았습니다.
///
/// 통신 실패가 아니라 사용자의 선택이므로 `AppError`가 아닙니다. 카카오·Apple native
/// adapter는 SDK의 취소 결과를 이 예외로 바꿉니다. Apple 웹 흐름의 취소는 복귀 결과
/// [AppleWebError.userCancelled]로 옵니다.
final class SocialSignInCancelled implements Exception {
  /// 취소.
  const new();

  @override
  String toString() => 'SocialSignInCancelled';
}

/// 제공자 설정(`config/auth.json`)이 비어 로그인할 수 없습니다(A81).
///
/// 외부 준비물이 오기 전의 빌드에서 버튼을 누르면 adapter가 던집니다. 버튼은 숨기지 않고,
/// 로그인 화면은 다른 실패와 같이 알립니다.
final class ProviderNotConfigured implements Exception {
  /// [provider]의 설정이 비었습니다.
  const new(this.provider);

  /// 설정이 빈 제공자.
  final SocialProvider provider;

  @override
  String toString() => 'ProviderNotConfigured(${provider.name})';
}

/// 카카오 로그인 결과. 계약 `KakaoLoginRequest`의 `idToken`입니다.
final class KakaoCredential {
  /// OIDC id_token을 담습니다.
  const new({required this.idToken});

  /// 카카오 OIDC id_token.
  final String idToken;
}

/// 카카오 로그인.
abstract interface class KakaoAuth {
  /// nonce 원문 [rawNonce]의 해시로 로그인하고 자격을 받습니다.
  /// 사용자가 취소하면 [SocialSignInCancelled], 그 밖의 실패는 `AppError`를 던집니다.
  Future<KakaoCredential> signIn({required String rawNonce});
}

/// LINE 로그인 결과. 계약 `LineLoginRequest`의 `idToken`입니다.
final class LineCredential {
  /// OIDC id_token을 담습니다.
  const new({required this.idToken});

  /// LINE OIDC id_token.
  final String idToken;
}

/// LINE 로그인.
abstract interface class LineAuth {
  /// nonce 원문 [rawNonce]의 해시로 로그인하고 자격을 받습니다.
  /// 사용자가 취소하면 [SocialSignInCancelled], 그 밖의 실패는 `AppError`를 던집니다.
  Future<LineCredential> signIn({required String rawNonce});
}

/// Google 로그인 결과. 계약 `GoogleLoginRequest`의 필드입니다.
final class GoogleCredential {
  /// id_token과 server에 보낼 nonce 원문을 담습니다.
  const new({required this.idToken, required this.rawNonce});

  /// Google OIDC id_token.
  final String idToken;

  /// id_token의 nonce에 해당하는 원문. SDK가 돌려준 값을 server에 그대로 보냅니다.
  final String rawNonce;
}

/// Google 로그인.
abstract interface class GoogleAuth {
  /// nonce 원문 [rawNonce]의 해시로 로그인하고 자격을 받습니다.
  /// 사용자가 취소하면 [SocialSignInCancelled], 그 밖의 실패는 `AppError`를 던집니다.
  Future<GoogleCredential> signIn({required String rawNonce});
}

/// iOS Apple 로그인 결과. 계약 `AppleLoginRequest`의 필드입니다.
final class AppleNativeCredential {
  /// identity_token과 authorization code를 담습니다.
  const new({required this.idToken, required this.authorizationCode});

  /// Apple identity_token.
  final String idToken;

  /// Apple authorization code.
  final String authorizationCode;
}

/// iOS 네이티브 Apple 로그인. 결과는 `loginApple`로 보냅니다.
abstract interface class AppleNativeAuth {
  /// nonce 원문 [rawNonce]의 해시로 로그인하고 자격을 받습니다.
  /// 사용자가 취소하면 [SocialSignInCancelled], 그 밖의 실패는 `AppError`를 던집니다.
  Future<AppleNativeCredential> signIn({required String rawNonce});
}

/// Android Apple 웹 로그인 복귀에서 실패한 이유입니다.
enum AppleWebError {
  /// 사용자가 취소함(`user_cancelled_authorize`).
  userCancelled,

  /// Apple 토큰 검증 실패(`token_invalid`).
  tokenInvalid,

  /// Apple 장애(`provider_unavailable`). 재시도할 수 있습니다.
  providerUnavailable,

  /// 잘못된 요청이거나 복귀 query가 형식에 맞지 않음(`invalid_request`).
  invalidRequest,

  /// 예상하지 못한 server 오류(`server_error`).
  serverError,

  /// 복귀 `state`가 app이 만든 값과 다름. 위조 가능성이 있어 교환 코드를 쓰지 않습니다.
  stateMismatch,

  /// 계약에 없는 `error` 값.
  unknown,
}

/// Android Apple 웹 로그인 복귀 결과입니다.
@immutable
sealed class AppleWebResult {
  const new();
}

/// 성공. 교환 코드를 `completeAppleWebLogin`에 nonce 원문과 함께 보냅니다.
final class AppleWebExchange extends AppleWebResult {
  /// 교환 코드를 담습니다.
  const new(this.exchangeCode);

  /// 일회용 교환 코드(2분).
  final String exchangeCode;

  @override
  bool operator ==(Object other) =>
      other is AppleWebExchange && other.exchangeCode == exchangeCode;

  @override
  int get hashCode => exchangeCode.hashCode;
}

/// 실패.
final class AppleWebFailure extends AppleWebResult {
  /// 실패 이유를 담습니다.
  const new(this.error);

  /// 실패 이유.
  final AppleWebError error;

  @override
  bool operator ==(Object other) =>
      other is AppleWebFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'AppleWebFailure($error)';
}

/// Android Apple 웹 로그인. authorize URL을 열고 App Link(또는 안내 페이지의
/// intent) 복귀를 받아 `state`를 확인한 결과를 돌려줍니다.
abstract interface class AppleWebAuth {
  /// nonce 원문 [rawNonce]의 해시로 authorize URL을 엽니다.
  /// 브라우저를 열지 못하는 등 통신 밖 실패는 `AppError`를 던집니다.
  Future<AppleWebResult> signIn({required String rawNonce});
}
