import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 그날 풀이(날의 성격 → 총운 문장 → 행운 칩 → 질문 카드) 자리의 skeleton.
///
/// 각 컴포넌트의 `states.loading.skeleton` 뼈(`day-character`,
/// `sentence-block` `card`, `lucky-card`, `guide-question-card`)를 오늘 화면의 지금 배치
/// 간격대로 놓습니다(결정 V66). 오늘 화면이 처음 불러올 때 `ScreenStateView.skeleton`으로 씁니다. 바깥 여백은
/// 쓰는 쪽이 정합니다.
class DayReadingSkeleton extends StatelessWidget {
  /// skeleton을 만듭니다. [guideCard]가 false면 질문 카드 자리를 두지 않습니다.
  const new({this.guideCard = true, super.key});

  /// 질문 카드 자리를 둘지.
  final bool guideCard;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      DayCharacter.skeleton(),
      const SizedBox(height: Space.s16),
      SentenceBlock.skeleton(variant: SentenceBlockVariant.card, index: 2),
      const SizedBox(height: Space.s24),
      LuckyCardRow.skeleton(index: 4),
      if (guideCard) ...[
        const SizedBox(height: Space.s24),
        GuideQuestionCard.skeleton(index: 7),
      ],
    ],
  );
}
