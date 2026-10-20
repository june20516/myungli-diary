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

  group('localeProvider(A60)', () {
    ProviderContainer containerOf(Locale device, Language? profile) {
      final container = ProviderContainer(
        overrides: [
          deviceLocaleProvider.overrideWithValue(device),
          profileLanguageProvider.overrideWithValue(profile),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('프로필 사본 언어가 없으면 기기 로케일 그대로다', () {
      expect(
        containerOf(const Locale('en', 'US'), null).read(localeProvider),
        const Locale('en', 'US'),
      );
    });

    test('사본 언어가 있으면 그 언어이고 국가 코드는 기기 값을 둔다', () {
      final container = containerOf(const Locale('ko', 'KR'), Language.en);
      expect(container.read(localeProvider), const Locale('en', 'KR'));
      expect(container.read(appLanguageProvider), Language.en);
      // 기기 지역 판정(D29·D58)은 앱 언어를 바꿔도 기기 지역을 따릅니다.
      expect(container.read(deviceRegionIsKoreaProvider), isTrue);
    });

    test('기본 profileLanguageProvider는 null이다(사본 연결은 app 계층)', () {
      final container = ProviderContainer(
        overrides: [
          deviceLocaleProvider.overrideWithValue(const Locale('ja', 'JP')),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLanguageProvider), isNull);
      expect(container.read(localeProvider), const Locale('ja', 'JP'));
    });
  });
}
