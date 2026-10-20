import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

/// tag-chip: good·bad·neutral.
Widget _tagChips() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        TagChip(
          name: ja ? '天乙貴人' : '천을귀인',
          variant: TagChipVariant.good,
          onTap: () {},
        ),
        TagChip(
          name: ja ? '沖' : '충',
          variant: TagChipVariant.bad,
          onTap: () {},
        ),
        TagChip(
          name: ja ? '駅馬' : '역마',
          variant: TagChipVariant.neutral,
          onTap: () {},
        ),
      ],
    );
  },
);

void main() {
  goldenTest('tag-chip: good·bad·neutral', (tester) async {
    await goldenMatrix(tester, 'diary_tag_chip', _tagChips);
  });
}
