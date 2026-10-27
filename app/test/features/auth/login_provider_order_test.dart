import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/auth/model/login_provider_order.dart';

void main() {
  const kakao = SocialProvider.kakao;
  const line = SocialProvider.line;
  const google = SocialProvider.google;
  const apple = SocialProvider.apple;

  test('ko는 카카오, LINE, Google, Apple', () {
    expect(loginProviderOrder(const Locale('ko')), [
      kakao,
      line,
      google,
      apple,
    ]);
  });

  test('ja는 LINE이 맨 위', () {
    expect(loginProviderOrder(const Locale('ja')), [
      line,
      kakao,
      google,
      apple,
    ]);
  });

  test('en은 Google이 맨 위', () {
    expect(loginProviderOrder(const Locale('en')), [
      google,
      kakao,
      line,
      apple,
    ]);
  });

  test('지원하지 않는 언어(zh)는 en 순서를 따릅니다', () {
    expect(loginProviderOrder(const Locale('zh')), [
      google,
      kakao,
      line,
      apple,
    ]);
  });

  test('ja_JP처럼 국가 코드가 붙어도 언어 코드로 판정합니다', () {
    expect(loginProviderOrder(const Locale('ja', 'JP')), [
      line,
      kakao,
      google,
      apple,
    ]);
    expect(loginProviderOrder(const Locale('ko', 'KR')), [
      kakao,
      line,
      google,
      apple,
    ]);
  });
}
