import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// '나' 꼬리표(`tag.me`): 내가 해당하는 칸(일간) 표시. 바탕 `action.primary`, 글자
/// `action.on-primary` 10 700 `font.family.ui`, `radius.full`.
///
/// 칸 위 오른쪽 모서리에 겹쳐 놓고 칸이 자르지 않습니다(`clippedByCell: false`). 놓는 일은 쓰는
/// 쪽(원국표)이 칸 밖 층에서 합니다.
class TagMe extends StatelessWidget {
  /// [label](예 "나") 꼬리표를 만듭니다.
  const new(this.label, {super.key});

  /// 꼬리표 글자.
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.actionPrimary,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          label,
          style: tokens.typography.labelMd.copyWith(
            color: tokens.colors.actionOnPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
