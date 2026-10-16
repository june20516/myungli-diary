import 'package:flutter/material.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 그날 풀이(날의 성격 배지 → 총운 문장 → 행운 칩 → 질문 카드) 자리의 skeleton.
///
/// 오늘 화면이 처음 불러올 때 `ScreenStateView.skeleton`으로 쓰고, 같은 내용을 보이는
/// 계획 4 `day-sheet`도 다시 씁니다(그래서 design에 둡니다). 바깥 여백은 쓰는 쪽이 정합니다. 글줄 높이는 기기 글자
/// 크기를 따라 실제 문장과 같은 높이로 둡니다.
class DayReadingSkeleton extends StatelessWidget {
  /// skeleton을 만듭니다. [guideCard]가 false면 질문 카드 자리를 두지 않습니다.
  const new({this.guideCard = true, super.key});

  /// 질문 카드 자리를 둘지.
  final bool guideCard;

  static const double _badgeWidth = 64;
  static const double _badgeHeight = 26;
  static const double _chipHeight = 34;
  static const List<double> _chipWidths = [76, 68, 52, 112];
  static const double _cardHeight = 168;
  static const int _sentenceLines = 3;

  @override
  Widget build(BuildContext context) {
    final style = context.tokens.typography.sentenceCard;
    final fontSize = MediaQuery.textScalerOf(context)
        .scale(style.fontSize ?? 18);
    final lineHeight = fontSize * (style.height ?? 1.6);
    final boneHeight = lineHeight * 0.6;
    var index = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBone(
          width: _badgeWidth,
          height: _badgeHeight,
          borderRadius: Radii.full,
          index: index++,
        ),
        const SizedBox(height: Space.s16),
        for (var i = 0; i < _sentenceLines; i++)
          Padding(
            padding: EdgeInsets.only(bottom: lineHeight - boneHeight),
            child: FractionallySizedBox(
              widthFactor: i == _sentenceLines - 1 ? 0.6 : 1,
              child: SkeletonBone(
                height: boneHeight,
                borderRadius: Radii.xs,
                index: index++,
              ),
            ),
          ),
        const SizedBox(height: Space.s16),
        Wrap(
          spacing: Space.s8,
          runSpacing: Space.s8,
          children: [
            for (final width in _chipWidths)
              SkeletonBone(
                width: width,
                height: _chipHeight,
                borderRadius: Radii.full,
                index: index++,
              ),
          ],
        ),
        if (guideCard) ...[
          const SizedBox(height: Space.s24),
          SkeletonBone(
            height: _cardHeight,
            borderRadius: Radii.lg,
            index: index++,
          ),
        ],
      ],
    );
  }
}
