import 'package:myungli_diary/core/api/gen/model/language.dart';

/// 계약에 없는 언어(REST 1.0.0 열린 enum, 결정 A78)는 기본 언어 `Language.en`으로 봅니다.
/// 기기 언어 판정(`resolveAppLanguage`)의 기본값과 같습니다. 아는 값은 그대로입니다.
///
/// 프로필 `language`를 로케일·요청·캐시 키·표시에 쓰는 곳은 이 함수를 거칩니다.
Language knownLanguageOf(Language language) =>
    language.isKnown ? language : Language.en;
