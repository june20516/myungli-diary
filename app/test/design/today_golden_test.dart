import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

/// day-character: 네 변형 × 이유 있음(링크 포함)·없음.
Widget _dayCharacters() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    String name(DayKind kind) => switch (kind) {
      DayKind.yongsinDay => ja ? '良い日' : '좋은 날',
      DayKind.gwiinDay => ja ? '貴人の日' : '귀인의 날',
      DayKind.gisinDay => ja ? '忌神の日' : '기신의 날',
      DayKind.ordinaryDay => ja ? '普通の日' : '평범한 날',
    };
    final reason = RenderedText(
      segments: [
        Segment(
          text: ja ? '今日は気の流れがあなたを助けてくれる日です。' : '오늘은 기운의 흐름이 나를 도와주는 날이에요.',
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s16,
      children: [
        for (final kind in DayKind.values) ...[
          DayCharacter(
            variant: dayCharacterVariantOf(kind),
            label: name(kind),
            reason: reason,
            reasonTrailing: DepthLink(
              variant: DepthLinkVariant.inlineEnd,
              label: ja ? '根拠を見る' : '근거 보기',
              onTap: () {},
            ),
          ),
          DayCharacter(variant: dayCharacterVariantOf(kind), label: name(kind)),
        ],
      ],
    );
  },
);

void main() {
  goldenTest('day-character: 네 변형 × 이유 있음·없음', (tester) async {
    await goldenMatrix(tester, 'today_day_character', _dayCharacters);
  });
}
