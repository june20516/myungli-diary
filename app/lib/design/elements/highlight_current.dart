import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 현재 강조 바탕(`highlight.current`, V93): [child] 뒤에 `color.highlight.bg`를 깝니다.
///
/// `onlyOn`: 흰 카드(`bg.sheet`) 위에서만 씁니다. 이 색은 화면 바탕(`bg.base`)과 같은 회색
/// 계열이라 화면 바탕 위에 두면 보이지 않습니다. 글자색 `action.primary` 700은 [child]가
/// 정합니다(외곽선 도장 없음).
class HighlightCurrent extends StatelessWidget {
  /// [child]에 강조 바탕을 깝니다.
  const new({required this.child, super.key});

  /// 강조할 칸.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.tokens.colors.highlightBg, child: child);
}
