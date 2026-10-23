import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';

/// 기기 로케일 [device]가 고르는 앱 언어. ko·ja는 그대로, 그 밖은 en입니다.
Language resolveAppLanguage(Locale device) => switch (device.languageCode) {
  'ko' => Language.ko,
  'ja' => Language.ja,
  _ => Language.en,
};

/// 계약에 없는 언어(REST 1.0.0 열린 enum, 결정 A78)는 기본 언어 `Language.en`으로 봅니다.
/// 기기 언어 판정([resolveAppLanguage])의 기본값과 같습니다. 아는 값은 그대로입니다.
Language knownLanguageOf(Language language) =>
    language.isKnown ? language : Language.en;

/// 화면 언어이자 프로필 `language`가 될 값.
final appLanguageProvider = Provider<Language>(
  (ref) => resolveAppLanguage(ref.watch(localeProvider)),
);

/// 기기 지역이 한국인지(D29·D58). 국가 코드가 없으면 false입니다.
final deviceRegionIsKoreaProvider = Provider<bool>(
  (ref) => ref.watch(localeProvider).countryCode == 'KR',
);
