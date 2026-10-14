import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';

void main() {
  test('resolveAppLanguage는 ko·ja는 그대로, 그 밖은 en이다', () {
    expect(resolveAppLanguage(const Locale('ko', 'KR')), Language.ko);
    expect(resolveAppLanguage(const Locale('ja')), Language.ja);
    expect(resolveAppLanguage(const Locale('en', 'US')), Language.en);
    expect(resolveAppLanguage(const Locale('fr', 'FR')), Language.en);
  });

  ProviderContainer containerWith(Locale locale) {
    final container = ProviderContainer(
      overrides: [localeProvider.overrideWithValue(locale)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('appLanguageProvider는 localeProvider에서 고른다', () {
    expect(
      containerWith(const Locale('ja', 'JP')).read(appLanguageProvider),
      Language.ja,
    );
  });

  test('deviceRegionIsKoreaProvider는 국가 코드가 KR일 때만 true다', () {
    expect(
      containerWith(const Locale('en', 'KR')).read(deviceRegionIsKoreaProvider),
      isTrue,
    );
    expect(
      containerWith(const Locale('ko')).read(deviceRegionIsKoreaProvider),
      isFalse,
    );
  });
}
