import 'dart:ui';

/// 줄바꿈 없는 결합자(WORD JOINER). 글자 사이에 두면 그 사이에서 줄이 바뀌지 않습니다.
const String wordJoiner = '⁠';

/// 한국어는 어절 단위로만 줄을 바꿉니다(명세 `wordBreak: keep-all`).
///
/// Flutter 줄바꿈은 한글 음절 사이에서도 끊을 수 있어서, [locale]이 한국어일 때 공백으로
/// 나뉜 어절 안의 글자 사이에 [wordJoiner]를 넣습니다. 다른 언어(영어는 원래 공백에서만,
/// 일본어는 글자 단위 + 금칙)는 그대로 돌려줍니다.
///
/// 결과는 화면에 그리는 용도입니다. 스크린리더 라벨과 풀이 키 같은 값에는 원문을 쓰고,
/// `TextSpan.semanticsLabel`에 원문을 넘기세요.
String applyKeepAll(Locale locale, String text) {
  if (locale.languageCode != 'ko') return text;
  final buffer = StringBuffer();
  int? previous;
  for (final rune in text.runes) {
    if (previous != null && !_isSpace(previous) && !_isSpace(rune)) {
      buffer.write(wordJoiner);
    }
    buffer.writeCharCode(rune);
    previous = rune;
  }
  return buffer.toString();
}

/// 공백(줄바꿈 기회가 있는 글자). 줄바꿈 없는 공백(U+00A0)은 공백으로 보지 않습니다.
bool _isSpace(int rune) =>
    rune == 0x20 ||
    rune == 0x09 ||
    rune == 0x0A ||
    rune == 0x0D ||
    rune == 0x3000;
