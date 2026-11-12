import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

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
          dayKind: HanjaTag(
            glyph: '用',
            label: ja ? '良い日' : '좋은 날',
            tone: HanjaTagTone.yongsin,
            onTap: () {},
          ),
          tags: [
            HanjaTag(glyph: '貴', label: ja ? '天乙貴人' : '천을귀인', onTap: () {}),
            HanjaTag(glyph: '合', label: ja ? '合' : '합', onTap: () {}),
          ],
          onTap: () {},
        ),
        DiaryRow(
          date: CalendarDate(2026, 10, 8),
          excerpt: ja ? '朝の空気が急に冷たくなった。' : '아침 공기가 갑자기 차가워졌다.',
          dayKindPending: true,
          onTap: () {},
        ),
        DiaryRow(
          date: CalendarDate(2026, 10, 2),
          excerpt: ja ? '会議で意見が分かれた。' : '회의에서 의견이 엇갈렸다.',
          dayKind: HanjaTag(
            glyph: '忌',
            label: ja ? '気をつける日' : '조심할 날',
            tone: HanjaTagTone.gisin,
            onTap: () {},
          ),
          tags: [HanjaTag(glyph: '沖', label: ja ? '沖' : '충', onTap: () {})],
          isLast: true,
          onTap: () {},
        ),
        const SizedBox(height: Space.s24),
        const DiaryRowSkeleton(),
      ],
    );
  },
);

/// diary-row 같은 날 여러 편: 묶음 카드(배지 → 줄 3개 → 태그)와 이어지는 한 편 줄, 빈 본문 줄이 낀 묶음.
Widget _diaryRowGroups() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiaryDayGroup(
          date: CalendarDate(2026, 10, 12),
          dayKind: HanjaTag(
            glyph: '用',
            label: ja ? '良い日' : '좋은 날',
            tone: HanjaTagTone.yongsin,
            onTap: () {},
          ),
          entries: [
            DiaryEntryData(
              createdAt: DateTime(2026, 10, 12, 8, 40),
              excerpt: ja ? '朝の空気が澄んでいて、散歩に出た。' : '아침 공기가 맑아서 산책을 나갔다.',
              onTap: () {},
            ),
            DiaryEntryData(
              createdAt: DateTime(2026, 10, 12, 13, 5),
              excerpt: ja
                  ? '久しぶりに連絡をくれた友達とお昼を食べた。話が長くなって午後の予定がずれたけれど、気分は良かった。'
                  : '오랜만에 연락이 온 친구와 점심을 먹었다. 이야기가 길어져 오후 일정이 밀렸지만 기분은 좋았다.',
              onTap: () {},
            ),
            DiaryEntryData(
              createdAt: DateTime(2026, 10, 12, 22, 30),
              excerpt: '',
              onTap: () {},
            ),
          ],
          // 한 줄을 넘는 날: 그 줄 안에서 가로로 밀고 끝 24만 흐립니다(V103).
          tags: [
            HanjaTag(glyph: '貴', label: ja ? '天乙貴人' : '천을귀인', onTap: () {}),
            HanjaTag(glyph: '合', label: ja ? '合' : '합', onTap: () {}),
            HanjaTag(glyph: '桃', label: ja ? '桃花' : '도화', onTap: () {}),
            HanjaTag(glyph: '驛', label: ja ? '駅馬' : '역마', onTap: () {}),
            HanjaTag(glyph: '華', label: ja ? '華蓋' : '화개', onTap: () {}),
          ],
        ),
        DiaryRow(
          date: CalendarDate(2026, 10, 8),
          excerpt: ja ? '朝の空気が急に冷たくなった。' : '아침 공기가 갑자기 차가워졌다.',
          dayKind: HanjaTag(
            glyph: '忌',
            label: ja ? '気をつける日' : '조심할 날',
            tone: HanjaTagTone.gisin,
            onTap: () {},
          ),
          isLast: true,
          onTap: () {},
        ),
      ],
    );
  },
);

/// diary-row entries: 오늘 바탕 카드, 그날 시트(머리 포함), skeleton 두 가지.
Widget _diaryEntries() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final entries = [
      DiaryEntryData(
        createdAt: DateTime(2026, 10, 12, 8, 40),
        excerpt: ja ? '朝の空気が澄んでいて、散歩に出た。' : '아침 공기가 맑아서 산책을 나갔다.',
        onTap: () {},
      ),
      DiaryEntryData(
        createdAt: DateTime(2026, 10, 12, 13, 5),
        excerpt: ja
            ? '久しぶりに連絡をくれた友達とお昼を食べた。話が長くなって午後の予定がずれたけれど、気分は良かった。'
            : '오랜만에 연락이 온 친구와 점심을 먹었다. 이야기가 길어져 오후 일정이 밀렸지만 기분은 좋았다.',
        onTap: () {},
      ),
      DiaryEntryData(
        createdAt: DateTime(2026, 10, 12, 22, 30),
        excerpt: '',
        onTap: () {},
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiaryEntries(entries: entries, surface: DiaryEntriesSurface.card),
        const SizedBox(height: Space.s24),
        DiaryEntries(entries: entries, surface: DiaryEntriesSurface.plain),
        const SizedBox(height: Space.s24),
        const DiaryEntriesSkeleton(),
        const SizedBox(height: Space.s24),
        const DiaryEntriesSkeleton(surface: DiaryEntriesSurface.plain),
      ],
    );
  },
);

/// diary-editor: edit(질문·빈 본문), edit 질문 뗀 자리(권유 줄, V102, #1013), view(도장·태그),
/// draft-indicator 세 상태.
Widget _editors() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final question = RenderedText(
      segments: [
        Segment(
          text: ja
              ? '今日目に留まった人や場面を一つ書いてみましょうか？'
              : '오늘 눈길이 갔던 사람이나 장면을 하나 적어 볼까요?',
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s16,
      children: [
        Row(
          spacing: Space.s16,
          children: [
            DraftIndicator(
              state: DraftIndicatorState.local,
              label: ja ? '下書き保存' : '기기에 저장됨',
            ),
            DraftIndicator(
              state: DraftIndicatorState.saved,
              label: ja ? '保存済み' : '저장됨',
            ),
          ],
        ),
        DiaryEditor.edit(
          date: CalendarDate(2026, 10, 13),
          controller: TextEditingController(),
          question: question,
          placeholder: ja ? '今日の出来事を書いてみましょう' : '오늘 있었던 일을 적어 보세요',
        ),
        DiaryEditor.edit(
          date: CalendarDate(2026, 10, 13),
          controller: TextEditingController(),
          question: question,
          questionDetached: true,
          onAttachQuestion: () {},
          placeholder: ja ? '今日の出来事を書いてみましょう' : '오늘 있었던 일을 적어 보세요',
        ),
        DiaryEditor.view(
          date: CalendarDate(2026, 10, 13),
          question: question,
          body: ja
              ? '会議で先に話を切り出したら、思ったより反応が良かった。'
              : '회의에서 먼저 말을 꺼냈더니 생각보다 반응이 좋았다.',
          tags: [
            HanjaTag(glyph: '貴', label: ja ? '天乙貴人' : '천을귀인', onTap: () {}),
            HanjaTag(glyph: '沖', label: ja ? '沖' : '충', onTap: () {}),
          ],
        ),
      ],
    );
  },
);

void main() {
  goldenTest('diary-editor: edit·질문 뗀 자리·view, draft-indicator', (
    tester,
  ) async {
    await goldenMatrix(tester, 'diary_editor', _editors);
  });

  goldenTest('diary-row: 달 머리·줄·배지 대기·마지막 줄·skeleton', (tester) async {
    await goldenMatrix(tester, 'diary_row', _diaryRows);
  });

  goldenTest('diary-row: 같은 날 묶음 카드(3편, 빈 본문 줄)', (tester) async {
    await goldenMatrix(tester, 'diary_row_group', _diaryRowGroups);
  });

  goldenTest('diary-row: entries(오늘 바탕·그날 시트 머리·skeleton)', (tester) async {
    await goldenMatrix(tester, 'diary_entries', _diaryEntries);
  });
}
