import 'package:flutter/material.dart';
import 'package:myungli_diary/design/elements/breathing.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// skeleton 자리 하나. 실제 요소와 같은 크기·반경으로 두고 먹 숨쉬기로 깜빡입니다.
class SkeletonBone extends StatelessWidget {
  /// 자리를 만듭니다.
  const new({
    required this.height,
    this.width,
    this.borderRadius = 0,
    this.index = 0,
    this.animated = true,
    super.key,
  });

  /// 너비. 없으면 부모가 주는 만큼.
  final double? width;

  /// 높이.
  final double height;

  /// 모서리 반경(실제 요소의 반경).
  final double borderRadius;

  /// 줄 순서. 줄마다 150ms씩 어긋납니다.
  final int index;

  /// false면 움직이지 않고 정지 상태로 그립니다(golden 등).
  final bool animated;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Breathing(
      index: index,
      animated: animated,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.tokens.colors.skeletonBone,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    ),
  );
}
