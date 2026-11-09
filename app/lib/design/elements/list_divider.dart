import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 목록 구분선(`list.divider`, V58): 같은 묶음 안 줄 사이에만 긋는 선입니다.
///
/// 두께는 `border.width.hairline`(0.5), 색은 `color.line`, 좌우는 줄 안쪽 여백(`paddingX`)과
/// 같은 `space.16`씩 들입니다. 첫 줄 위와 끝 줄 아래에는 두지 않고, 묶음과 묶음은 선 없이
/// 간격으로 나눕니다.
class ListDivider extends StatelessWidget {
  /// 구분선을 만듭니다. 들임은 읽는 방향 기준 시작, 끝입니다.
  const new({
    this.indentStart = Space.s16,
    this.indentEnd = Space.s16,
    super.key,
  });

  /// 시작 쪽 들임.
  final double indentStart;

  /// 끝 쪽 들임.
  final double indentEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: indentStart, end: indentEnd),
    child: ColoredBox(
      color: context.tokens.colors.line,
      child: const SizedBox(
        height: BorderTokens.hairline,
        width: double.infinity,
      ),
    ),
  );
}
