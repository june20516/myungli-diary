import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 글자 링크의 이름 + 끝 화살표(`chevron`, 결정 V29).
///
/// `depth-link`(`inline-end`·`block`·`navigate`), `sentence-block` `locked`의
/// "열기", 근거 잠금 안내의 광고 제거권 링크(`lockPanel.pass`)가 함께 씁니다. 화살표는 원고에 넣지
/// 않고 이 위젯이 그립니다. 명세는 아이콘 `caret-right` Regular, 크기는 링크 글자 크기, 색은
/// 링크 색, 간격 2px, 장식입니다.
///
/// 화살표는 아이콘 글꼴의 글리프를 글자 조각(`TextSpan`)으로 이어 붙여 [style]의 크기·색을
/// 그대로 이어받습니다. 링크가 감기면 화살표는 마지막 줄 끝을 따라가고, 앞의 단어 연결 문자
/// (U+2060)가 화살표만 다음 줄로 넘어가지 않게 붙듭니다. 2px 간격은 그 연결 문자의 자간으로
/// 둡니다(글자 폭 0 + 자간 2). `WidgetSpan`은 자리표시자 앞에서 줄이 끊겨 화살표가 홀로
/// 남으므로 쓰지 않습니다.
///
/// 이 위젯은 의미 노드를 만들지 않습니다. 감싸는 누름 자리(`PressInkTarget`)가 링크 이름
/// 하나로 읽으므로 화살표와 연결 문자는 스크린리더에 들어가지 않습니다.
class LinkLabel extends StatelessWidget {
  /// 링크 이름 [label]에 화살표를 붙여 그립니다.
  const new({
    required this.label,
    required this.style,
    this.softWrap = true,
    this.textAlign = TextAlign.start,
    super.key,
  });

  /// 화살표 아이콘(`caret-right` Regular).
  static const IconData caret = PhosphorIconsRegular.caretRight;

  /// 링크 이름과 화살표 사이 간격(px).
  static const double gap = 2;

  /// 줄바꿈을 막는 단어 연결 문자(WORD JOINER).
  static const String wordJoiner = '\u2060';

  /// 링크 이름(원고 그대로, 화살표 없음).
  final String label;

  /// 링크 글자 스타일(글자 크기·링크 색). 화살표도 이 크기·색입니다.
  final TextStyle style;

  /// false면 한 줄로 둡니다(`inline-end`처럼 링크 전체가 한 덩어리인 곳).
  final bool softWrap;

  /// 줄 정렬.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Text.rich(
    span(label),
    softWrap: softWrap,
    textAlign: textAlign,
    style: style,
  );

  /// [label] + 연결 문자(자간 [gap]) + 화살표 글리프 조각. 스타일은 바깥에서 이어받습니다.
  static TextSpan span(String label) => TextSpan(
    text: label,
    children: [
      const TextSpan(
        text: wordJoiner,
        style: TextStyle(letterSpacing: gap),
      ),
      TextSpan(
        text: String.fromCharCode(caret.codePoint),
        style: TextStyle(
          fontFamily: caret.fontFamily,
          package: caret.fontPackage,
          fontFamilyFallback: caret.fontFamilyFallback,
          letterSpacing: 0,
        ),
      ),
    ],
  );
}
