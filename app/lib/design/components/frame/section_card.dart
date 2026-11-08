import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 섹션 내용 흰 카드(`bg.sheet`, `radius.lg`, 안쪽 [padding], 결정 V78).
///
/// 폭은 채웁니다. 오늘, 나의 사주, 사주 표 화면의 섹션이 함께 씁니다.
class SectionCard extends StatelessWidget {
  /// [child]를 카드에 담습니다. [padding]을 안 주면 `space.16`입니다.
  const new({
    required this.child,
    this.padding = const EdgeInsets.all(Space.s16),
    super.key,
  });

  /// 카드 내용.
  final Widget child;

  /// 안쪽 여백.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.colors.bgSheet,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}
