import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
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

/// 같은 날 여러 편: 묶음 카드와 이어지는 한 편 줄(`diary-row` `day`).
class _DiaryGroupDemo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DiaryDayGroup(
        date: CalendarDate(2026, 10, 12),
        character: DayCharacterVariant.good,
        characterLabel: '좋은 날',
        entries: _entries(),
        tag: TagChip(name: '천을귀인', variant: TagChipVariant.good, onTap: () {}),
      ),
      DiaryRow(
        date: CalendarDate(2026, 10, 8),
        excerpt: '아침 공기가 갑자기 차가워졌다.',
        isLast: true,
        onTap: () {},
      ),
    ],
  );
}

List<DiaryEntryData> _entries() => [
  DiaryEntryData(
    createdAt: DateTime(2026, 10, 12, 8, 40),
    excerpt: '아침 공기가 맑아서 산책을 나갔다.',
    onTap: () {},
  ),
  DiaryEntryData(
    createdAt: DateTime(2026, 10, 12, 13, 5),
    excerpt: '오랜만에 연락이 온 친구와 점심을 먹었다. 이야기가 길어져 오후 일정이 밀렸지만 기분은 좋았다.',
    onTap: () {},
  ),
  DiaryEntryData(
    createdAt: DateTime(2026, 10, 12, 22, 30),
    excerpt: '',
    onTap: () {},
  ),
];

/// diary-editor edit: 저장 순간 버튼으로 도장·태그 칩 순서를 봅니다.
class _EditorDemo extends StatefulWidget {
  const new();

  @override
  State<_EditorDemo> createState() => _EditorDemoState();
}

class _EditorDemoState extends State<_EditorDemo> {
  final _controller = TextEditingController();
  final _editor = DiaryEditorController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: Space.s16,
    children: [
      const DraftIndicator(state: DraftIndicatorState.local, label: '기기에 저장됨'),
      DiaryEditor.edit(
        date: CalendarDate(2026, 10, 13),
        controller: _controller,
        editorController: _editor,
        question: RenderedText(
          segments: [Segment(text: '오늘 눈길이 갔던 사람이나 장면을 하나 적어 볼까요?')],
        ),
        placeholder: '오늘 있었던 일을 적어 보세요',
      ),
      TextButton(
        onPressed: () => _editor.playSaveSequence([
          TagChip(name: '천을귀인', variant: TagChipVariant.good, onTap: () {}),
        ]),
        child: const Text('저장 순간'),
      ),
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
        WidgetbookUseCase(
          name: '같은 날 여러 편(묶음 카드)',
          builder: (context) => const Stage(
            child: SizedBox(width: 360, child: _DiaryGroupDemo()),
          ),
        ),
        WidgetbookUseCase(
          name: 'entries(오늘 바탕)',
          builder: (context) => Stage(
            child: SizedBox(
              width: 360,
              child: DiaryEntries(
                entries: _entries(),
                surface: DiaryEntriesSurface.card,
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'entries(그날 시트 머리)',
          builder: (context) => Stage(
            child: SizedBox(
              width: 360,
              child: DiaryEntries(
                entries: _entries(),
                surface: DiaryEntriesSurface.plain,
                head: '이날 일기 3편',
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'entries skeleton',
          builder: (context) => const Stage(
            child: SizedBox(width: 360, child: DiaryEntriesSkeleton()),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'diary-editor',
      useCases: [
        WidgetbookUseCase(
          name: 'edit + 저장 순간',
          builder: (context) => const Stage(
            child: SizedBox(
              width: 360,
              child: SingleChildScrollView(child: _EditorDemo()),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'view',
          builder: (context) => Stage(
            child: SizedBox(
              width: 360,
              child: DiaryEditor.view(
                date: CalendarDate(2026, 10, 13),
                body: '회의에서 먼저 말을 꺼냈더니 생각보다 반응이 좋았다.',
                tags: [
                  TagChip(
                    name: '천을귀인',
                    variant: TagChipVariant.good,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
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
