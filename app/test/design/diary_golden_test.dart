import 'package:flutter/material.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
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

/// diary-row: 달 머리, 배지·태그 있는 줄, 배지 대기 줄, 마지막 줄, skeleton 줄.
Widget _diaryRows() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiaryMonthHeader(label: ja ? '2026年10月' : '2026년 10월'),
        const SizedBox(height: Space.s12),
        DiaryRow(
          date: CalendarDate(2026, 10, 12),
          excerpt: ja
              ? '久しぶりに連絡をくれた友達とお昼を食べた。話が長くなって午後の予定がずれたけれど、気分は良かった。'
              : '오랜만에 연락이 온 친구와 점심을 먹었다. 이야기가 길어져 오후 일정이 밀렸지만 기분은 좋았다.',
          character: DayCharacterVariant.good,
          characterLabel: ja ? '良い日' : '좋은 날',
          tag: TagChip(
            name: ja ? '天乙貴人' : '천을귀인',
            variant: TagChipVariant.good,
            onTap: () {},
          ),
          onTap: () {},
        ),
        DiaryRow(
          date: CalendarDate(2026, 10, 8),
          excerpt: ja ? '朝の空気が急に冷たくなった。' : '아침 공기가 갑자기 차가워졌다.',
          characterPending: true,
          onTap: () {},
        ),
        DiaryRow(
          date: CalendarDate(2026, 10, 2),
          excerpt: ja ? '会議で意見が分かれた。' : '회의에서 의견이 엇갈렸다.',
          character: DayCharacterVariant.gisin,
          characterLabel: ja ? '気をつける日' : '조심할 날',
          tag: TagChip(
            name: ja ? '沖' : '충',
            variant: TagChipVariant.bad,
            onTap: () {},
          ),
          isLast: true,
          onTap: () {},
        ),
        const SizedBox(height: Space.s24),
        const DiaryRowSkeleton(),
      ],
    );
  },
);

void main() {
  goldenTest('diary-row: 달 머리·줄·배지 대기·마지막 줄·skeleton', (tester) async {
    await goldenMatrix(tester, 'diary_row', _diaryRows);
  });

  goldenTest('tag-chip: good·bad·neutral', (tester) async {
    await goldenMatrix(tester, 'diary_tag_chip', _tagChips);
  });
}
