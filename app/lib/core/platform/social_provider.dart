/// 소셜 로그인 제공자(`social-login-button` `variants`).
///
/// 값의 순서는 명세의 기본 순서(`parts.stack.order.base`)입니다. 언어마다 맨 위에 올 제공자는
/// 화면이 정합니다(`parts.stack.order.top`).
enum SocialProvider {
  /// 카카오 로그인.
  kakao,

  /// LINE으로 로그인.
  line,

  /// Google 계정으로 로그인.
  google,

  /// Apple로 로그인(iOS·Android 모두, Android는 웹 흐름).
  apple,
}
