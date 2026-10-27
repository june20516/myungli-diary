import 'dart:ui';

import 'package:myungli_diary/core/platform/social_provider.dart';

/// 언어마다 맨 위에 올리는 제공자(`social-login-button` `parts.stack.order.top`).
const Map<String, SocialProvider> _topByLanguage = {
  'ko': SocialProvider.kakao,
  'ja': SocialProvider.line,
  'en': SocialProvider.google,
};

/// 로그인 버튼의 세로 순서(D82 ①).
///
/// 기본 순서(카카오, LINE, Google, Apple, [SocialProvider.values])에서 앱 언어의 대표
/// 제공자만 맨 위로 올립니다. 지원하지 않는 언어는 en 순서를 따르고, `ja_JP`처럼
/// 국가 코드가 붙어도 언어 코드로 판정합니다. 로그인 수단과 계정 합치기 인증 단계도
/// 이 함수를 씁니다.
List<SocialProvider> loginProviderOrder(Locale locale) {
  final top = _topByLanguage[locale.languageCode] ?? _topByLanguage['en']!;
  return [top, ...SocialProvider.values.where((provider) => provider != top)];
}
