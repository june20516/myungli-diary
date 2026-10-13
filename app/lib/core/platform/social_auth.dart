/// 카카오 로그인 결과. 계약 `KakaoLoginRequest`의 `idToken`입니다.
final class KakaoCredential {
  /// OIDC id_token을 담습니다.
  const new({required this.idToken});

  /// 카카오 OIDC id_token.
  final String idToken;
}

/// 카카오 로그인.
abstract interface class KakaoAuth {
  /// [nonce]를 넣어 로그인하고 자격을 받습니다. 실패하면 `AppError`를 던집니다.
  Future<KakaoCredential> signIn({required String nonce});
}

/// Apple 로그인 흐름. 계약 `AppleLoginRequest.clientType`입니다.
enum AppleClientType {
  /// iOS 네이티브 흐름.
  native,

  /// Android 웹 흐름.
  web,
}

/// Apple 로그인 결과. 계약 `AppleLoginRequest`의 필드와 같습니다.
final class AppleCredential {
  /// identity_token과 authorization code를 담습니다.
  const new({
    required this.idToken,
    required this.authorizationCode,
    required this.clientType,
  });

  /// Apple identity_token.
  final String idToken;

  /// Apple authorization code.
  final String authorizationCode;

  /// 로그인 흐름.
  final AppleClientType clientType;
}

/// Apple 로그인.
abstract interface class AppleAuth {
  /// [nonce]·[state]를 넣어 로그인하고 자격을 받습니다. 실패하면 `AppError`를 던집니다.
  Future<AppleCredential> signIn({
    required String nonce,
    required String state,
  });
}
