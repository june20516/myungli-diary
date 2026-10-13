import 'package:flutter/painting.dart';

/// 줄바꿈 없는 결합자(WORD JOINER). 글자 사이에 두면 그 사이에서 줄이 바뀌지 않습니다.
const String wordJoiner = '⁠';

/// 한국어는 어절 단위로만 줄을 바꿉니다(명세 `wordBreak: keep-all`).
///
/// Flutter 줄바꿈은 한글 음절 사이에서도 끊을 수 있어서, [locale]이 한국어일 때 공백으로
/// 나뉜 어절 안에서 **한글이 닿아 있는 글자 사이**에 [wordJoiner]를 넣습니다. 다른 언어
/// (영어는 원래 공백에서만, 일본어는 글자 단위 + 금칙)는 그대로 돌려줍니다.
///
/// 끊으면 안 되는 자리에만 넣는 방식이라 아래는 건드리지 않습니다. 이모지 ZWJ 시퀀스나
/// 서로게이트 쌍(BMP 밖 글자), 결합 부호(Mn·Mc·Me), 변이 선택자는 둘 다 한글이 아니면
/// 원래 끊기지 않거나 끊어도 되는 자리이고, 한글 옆에 붙어 있어도 그 자리에는 넣지 않아
/// 글자 조합이 깨지지 않게 합니다.
///
/// 결과는 화면에 그리는 용도입니다. 스크린리더 라벨과 풀이 키 같은 값에는 원문을 쓰고,
/// `TextSpan.semanticsLabel`에 원문을 넘기세요.
String applyKeepAll(Locale locale, String text) {
  if (locale.languageCode != 'ko') return text;
  final buffer = StringBuffer();
  int? previous;
  for (final rune in text.runes) {
    if (previous != null && _canJoin(previous, rune)) buffer.write(wordJoiner);
    buffer.writeCharCode(rune);
    previous = rune;
  }
  return buffer.toString();
}

/// [applyKeepAll]한 글자를 그릴 span들. 결합자마다 자간을 0으로 둔 span으로 가릅니다.
///
/// 자간(`letterSpacing`)은 글자마다 얹히므로 제로 폭 결합자에도 붙어 어절 폭이 달라집니다.
/// 결합자 span은 자간 0이고 스크린리더 라벨이 비어 있어, 폭과 낭독은 원문과 같습니다.
List<InlineSpan> keepAllSpans(Locale locale, String text) {
  final parts = applyKeepAll(locale, text).split(wordJoiner);
  return [
    for (var i = 0; i < parts.length; i++) ...[
      if (i > 0)
        const TextSpan(
          text: wordJoiner,
          semanticsLabel: '',
          style: TextStyle(letterSpacing: 0),
        ),
      if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
    ],
  ];
}

/// 두 글자 사이에 결합자를 넣어도 되는지: 둘 다 BMP, 둘 중 하나는 한글, 어느 쪽도 공백·
/// 결합자·ZWJ·변이 선택자·결합 부호가 아닙니다.
bool _canJoin(int before, int after) =>
    (_isHangul(before) || _isHangul(after)) &&
    _isPlain(before) &&
    _isPlain(after);

bool _isPlain(int rune) =>
    rune <= 0xFFFF &&
    !_isSpace(rune) &&
    rune != 0x2060 &&
    rune != 0x200D &&
    !(rune >= 0xFE00 && rune <= 0xFE0F) &&
    !_combining.hasMatch(String.fromCharCode(rune));

/// 결합 부호: Mn·Mc·Me.
final RegExp _combining = RegExp(r'\p{M}', unicode: true);

bool _isHangul(int rune) =>
    (rune >= 0x1100 && rune <= 0x11FF) ||
    (rune >= 0x3130 && rune <= 0x318F) ||
    (rune >= 0xA960 && rune <= 0xA97F) ||
    (rune >= 0xAC00 && rune <= 0xD7AF) ||
    (rune >= 0xD7B0 && rune <= 0xD7FF);

/// 공백(줄바꿈 기회가 있는 글자). 줄바꿈 없는 공백(U+00A0)은 공백으로 보지 않습니다.
bool _isSpace(int rune) =>
    rune == 0x20 ||
    rune == 0x09 ||
    rune == 0x0A ||
    rune == 0x0D ||
    rune == 0x3000;
