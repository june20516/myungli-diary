import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
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

/// 일기 컴포넌트(`diary.json`).
final WidgetbookFolder diaryDirectory = WidgetbookFolder(
  name: '일기',
  children: [
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
