import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';

/// 제공자 버튼의 공식 문구(`ui.login.provider`, "카카오 로그인"·"LINE으로 로그인").
///
/// `SocialProvider`가 design에 있어 `lib/core/l10n`(design을 모름) 대신 컴포넌트 옆에 둡니다.
String socialProviderLabel(AppLocalizations l10n, SocialProvider provider) =>
    switch (provider) {
      SocialProvider.kakao => l10n.loginKakaoLabel,
      SocialProvider.line => l10n.loginLineLabel,
      SocialProvider.google => l10n.loginGoogleLabel,
      SocialProvider.apple => l10n.loginAppleLabel,
    };

/// 제공자 이름(`ui.login-methods.row`, "카카오"·"LINE"). `connected` 줄과 계정 카드의 수단
/// 이름에 씁니다.
String socialProviderName(AppLocalizations l10n, SocialProvider provider) =>
    switch (provider) {
      SocialProvider.kakao => l10n.loginProviderKakao,
      SocialProvider.line => l10n.loginProviderLine,
      SocialProvider.google => l10n.loginProviderGoogle,
      SocialProvider.apple => l10n.loginProviderApple,
    };
