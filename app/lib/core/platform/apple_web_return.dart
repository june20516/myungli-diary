// Android Apple 웹 로그인의 authorize URL과 App Link 복귀 해석입니다
// (server spec `2026-10-13-apple-web-callback-design.md`, 결정 S22).

import 'package:myungli_diary/core/platform/social_auth.dart';

/// 계약 `AppleWebLoginRequest.exchangeCode` 형식(256비트 난수의 base64url, 패딩 없음).
final _exchangeCodePattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

const Map<String, AppleWebError> _errorValues = {
  'user_cancelled_authorize': AppleWebError.userCancelled,
  'token_invalid': AppleWebError.tokenInvalid,
  'provider_unavailable': AppleWebError.providerUnavailable,
  'invalid_request': AppleWebError.invalidRequest,
  'server_error': AppleWebError.serverError,
};

/// Apple authorize URL입니다. `scope`는 보내지 않습니다.
///
/// [hashedNonce]는 `hashNonce(원문)`이고 [state]는 app이 만든 무작위 값입니다.
Uri buildAppleAuthorizeUri({
  required String clientId,
  required Uri redirectUri,
  required String hashedNonce,
  required String state,
}) {
  return Uri.https('appleid.apple.com', '/auth/authorize', {
    'client_id': clientId,
    'redirect_uri': redirectUri.toString(),
    'response_mode': 'form_post',
    'response_type': 'code id_token',
    'nonce': hashedNonce,
    'state': state,
  });
}

/// App Link `/auth/apple` 복귀 [link]를 해석합니다.
///
/// `state`가 [expectedState]와 다르면 다른 값과 관계없이 실패입니다.
/// `error`가 있으면 `exchange`보다 우선합니다.
AppleWebResult parseAppleWebReturn(Uri link, {required String expectedState}) {
  final query = link.queryParameters;
  if (query['state'] != expectedState) {
    return const AppleWebFailure(AppleWebError.stateMismatch);
  }
  final error = query['error'];
  if (error != null) {
    return AppleWebFailure(_errorValues[error] ?? AppleWebError.unknown);
  }
  final exchange = query['exchange'];
  if (exchange == null || !_exchangeCodePattern.hasMatch(exchange)) {
    return const AppleWebFailure(AppleWebError.invalidRequest);
  }
  return AppleWebExchange(exchange);
}
