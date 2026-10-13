import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 용어 표시 요소: `term.bg` 바탕, `term.fg` 글자, `radius.xs`, 가로 3px.
///
/// 굵게 하지 않고 놓인 글자 스타일을 그대로 따릅니다(결정 V0).
class TermMark extends StatelessWidget {
  /// 용어 표시를 만듭니다.
  const new(this.text, {super.key});

  /// 용어 글자.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.termBg,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(text, style: TextStyle(color: colors.termFg)),
      ),
    );
  }
}
