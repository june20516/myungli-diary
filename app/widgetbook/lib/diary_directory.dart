import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/date_block.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

/// 날의 성격 `hanja-tag`(귀인의 날, 길흉 톤, V81).
HanjaTag _dayKindTag() => HanjaTag(
  glyph: HanjaGlyphs.forDayKind(DayKind.gwiinDay),
  label: '귀인의 날',
  tone: HanjaGlyphs.toneOfDayKind(DayKind.gwiinDay),
  onTap: () {},
);

/// 대표 태그 `hanja-tag`(사주 용어 초록 `default`).
HanjaTag _featuredTag() => HanjaTag(
  glyph: HanjaGlyphs.forTagKey('cheoneul_gwiin')!,
  label: '천을귀인',
  onTap: () {},
);

/// diary-row 목록: 달 머리, 날의 성격과 대표 태그 줄, 성격 대기, 마지막 줄, skeleton.
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
        dayKind: _dayKindTag(),
        tag: _featuredTag(),
        onTap: () {},
      ),
      DiaryRow(
        date: CalendarDate(2026, 10, 8),
        excerpt: '아침 공기가 갑자기 차가워졌다.',
        dayKindPending: true,
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
        dayKind: _dayKindTag(),
        entries: _entries(),
        tag: _featuredTag(),
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

/// 질문 바꾸기 후보(같은 질문의 다른 변주, 대표 태그 2순위).
const List<String> _questions = [
  '오늘 눈길이 갔던 사람이나 장면을 하나 적어 볼까요?',
  '오늘 들은 말 중에 기억에 남는 게 있나요?',
  '오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?',
];

/// diary-editor edit: 질문 바꾸기로 후보를 돌고, 저장 순간 버튼으로 도장·대표 태그 순서를
/// 봅니다.
class _EditorDemo extends StatefulWidget {
  const new();

  @override
  State<_EditorDemo> createState() => _EditorDemoState();
}

class _EditorDemoState extends State<_EditorDemo> {
  final _controller = TextEditingController();
  final _editor = DiaryEditorController();
  int _question = 0;

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
          segments: [Segment(text: _questions[_question])],
        ),
        onSwapQuestion: () =>
            setState(() => _question = (_question + 1) % _questions.length),
        placeholder: '오늘 있었던 일을 적어 보세요',
      ),
      TextButton(
        onPressed: () => _editor.playSaveSequence([
          HanjaTag(glyph: '貴', label: '천을귀인', onTap: () {}),
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
          name: 'entries(그날 시트 plain)',
          builder: (context) => Stage(
            child: SizedBox(
              width: 360,
              child: DiaryEntries(
                entries: _entries(),
                surface: DiaryEntriesSurface.plain,
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
      name: 'date-block',
      useCases: [
        WidgetbookUseCase(
          name: '일진 있음',
          builder: (context) => const Stage(
            child: DateBlock(
              day: '5',
              monthWeekday: '11월 목요일',
              iljin: '癸未(계미)일',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '일진 불러오는 중',
          builder: (context) => const Stage(
            child: DateBlock(
              day: '5',
              monthWeekday: '11월 목요일',
              iljinLoading: true,
            ),
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
                tags: [HanjaTag(glyph: '貴', label: '천을귀인', onTap: () {})],
              ),
            ),
          ),
        ),
      ],
    ),
  ],
);
