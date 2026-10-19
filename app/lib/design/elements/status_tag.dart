import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 상태 꼬리표 요소(`elements.json` `tag.status`): 옅은 sage 알약.
///
/// 일정 요약의 "진행 중"·"다음", 대운 "지금"·세운 "올해"에 씁니다. 글자는 쓰는 쪽이
/// ARB에서 읽어 넘깁니다.
class StatusTag extends StatelessWidget {
  /// 꼬리표를 만듭니다.
  const new(this.label, {super.key});

  /// 안쪽 여백(`padding` x 8, y 2).
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 2,
  );

  /// 꼬리표 글자.
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.statusBg,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
      ),
      child: Padding(
        padding: padding,
        child: Text(
          label,
          style: tokens.typography.labelMd.copyWith(
            color: tokens.colors.statusFg,
          ),
        ),
      ),
    );
  }
}
