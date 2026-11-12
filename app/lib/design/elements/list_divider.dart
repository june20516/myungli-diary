import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 목록 구분선(`list.divider`, V58): 같은 묶음 안 줄 사이에만 긋는 선입니다.
///
/// 두께는 `border.width.hairline`(0.5), 색은 `color.line`, 좌우는 줄 안쪽 여백(`paddingX`)과
/// 같은 [insetX]씩 들입니다. 첫 줄 위와 끝 줄 아래에는 두지 않고, 묶음과 묶음은 선 없이
/// 간격으로 나눕니다. 묶음 카드 없이 시트 본문에 바로 놓인 목록과 구역(행운 색 둘 시트 두 색
/// 사이, 사주 기운 시트 문장 목록)은 [ListDivider.inSheet]로 들임 없이 긋습니다(V124).
class ListDivider extends StatelessWidget {
  /// 구분선을 만듭니다. 들임은 읽는 방향 기준 시작, 끝입니다.
  const new({this.indentStart = insetX, this.indentEnd = insetX, super.key});

  /// 시트 본문에 바로 놓인 목록과 구역의 구분선(`list.divider` `inSheet`, 들임 [inSheetInsetX]).
  const new inSheet({super.key})
    : indentStart = inSheetInsetX,
      indentEnd = inSheetInsetX;

  /// 묶음 카드 안 들임(`list.divider.insetX`, `space.16`).
  static const double insetX = Space.s16;

  /// 시트 본문에 바로 놓인 목록의 들임(`list.divider.inSheet.insetX`, 0).
  static const double inSheetInsetX = 0;

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
