import 'package:flutter/material.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

/// tag-chip 세 변형.
class _TagChipDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.s8,
    runSpacing: Space.s8,
    children: [
      TagChip(name: '천을귀인', variant: TagChipVariant.good, onTap: () {}),
      TagChip(name: '충', variant: TagChipVariant.bad, onTap: () {}),
      TagChip(name: '역마', variant: TagChipVariant.neutral, onTap: () {}),
    ],
  );
}

/// diary-row 목록: 달 머리, 배지·태그 줄, 배지 대기, 마지막 줄, skeleton.
class _DiaryRowDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DiaryMonthHeader(label: '2026년 10월'),
      const SizedBox(height: Space.s12),
      DiaryRow(
        date: CalendarDate(2026, 10, 12),
        excerpt: '오랜만에 연락이 온 친구와 점심을 먹었다. 이야기가 길어져 오후 일정이 밀렸지만 기분은 좋았다.',
        character: DayCharacterVariant.good,
        characterLabel: '좋은 날',
        tag: TagChip(name: '천을귀인', variant: TagChipVariant.good, onTap: () {}),
        onTap: () {},
      ),
      DiaryRow(
        date: CalendarDate(2026, 10, 8),
        excerpt: '아침 공기가 갑자기 차가워졌다.',
        characterPending: true,
        onTap: () {},
      ),
      DiaryRow(
        date: CalendarDate(2026, 10, 2),
        excerpt: '회의에서 의견이 엇갈렸다.',
        isLast: true,
        onTap: () {},
      ),
      const SizedBox(height: Space.s24),
      const DiaryRowSkeleton(),
    ],
  );
}

/// 일기 컴포넌트(`diary.json`).
final WidgetbookFolder diaryDirectory = WidgetbookFolder(
  name: '일기',
  children: [
    WidgetbookComponent(
      name: 'diary-row',
      useCases: [
        WidgetbookUseCase(
          name: '목록',
          builder: (context) =>
              const Stage(child: SizedBox(width: 360, child: _DiaryRowDemo())),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'tag-chip',
      useCases: [
        WidgetbookUseCase(
          name: '변형',
          builder: (context) => const Stage(child: _TagChipDemo()),
        ),
      ],
    ),
  ],
);
