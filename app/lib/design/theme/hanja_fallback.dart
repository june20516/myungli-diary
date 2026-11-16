import 'package:flutter/painting.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// server 콘텐츠 문장의 한자 대체 글꼴(`fontFallback: {font.family.hanja}`, design 결정 V113,
/// V134).
///
/// 문장 글꼴(ko 고운돋움, en Pretendard)에는 한자 글리프가 없어, 한자만 `font.family.hanja`로
/// 그립니다. 그 family에도 없는 글자(괴강 魁罡의 罡)는 토큰이 정한 그 family의 대체
/// 글꼴(`Myungli Hanja Supplement`, A137)로 이어 그리므로 family 이름과 그 대체 목록을 함께
/// 돌려줍니다. 대체 글꼴은 앞 글꼴에 없는 글자에만 쓰여, 한자가 없는 문장과 한자가 있는 ja 문장
/// 글꼴은 모양이 같습니다.
List<String> hanjaFallbackFamilies(TypeTokens typography) {
  final hanja = typography.hanjaPillar;
  final family = hanja.fontFamily;
  return family == null ? const [] : [family, ...?hanja.fontFamilyFallback];
}

/// [style]의 대체 글꼴 맨 앞에 [hanjaFallbackFamilies]를 끼웁니다.
TextStyle withHanjaFallback(TextStyle style, TypeTokens typography) =>
    style.copyWith(
      fontFamilyFallback: [
        ...hanjaFallbackFamilies(typography),
        ...?style.fontFamilyFallback,
      ],
    );
