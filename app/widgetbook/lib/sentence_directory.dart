import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

final RenderedText _sample = RenderedText(
  segments: [
    Segment(text: '오늘은 '),
    Segment(text: '식신', term: 'TenGod.SIKSIN'),
    Segment(text: '의 기운이 강해서 마음에 담아 둔 말을 꺼내기 좋은 날이에요.'),
  ],
);

RenderedText _line(String text) =>
    RenderedText(segments: [Segment(text: text)]);

/// 문장 카탈로그: sentence-block, term-token, depth-link, reaction-button.
final WidgetbookFolder sentenceDirectory = WidgetbookFolder(
  name: '문장',
  children: [
    WidgetbookComponent(
      name: 'sentence-block',
      useCases: [
        for (final variant in SentenceBlockVariant.values)
          WidgetbookUseCase(
            name: variant.name,
            builder: (context) => Stage(
              child: SentenceBlock(
                variant: variant,
                text: _sample,
                termStyle: variant == SentenceBlockVariant.preview
                    ? null
                    : TermStyle.chip,
                onTerm: variant == SentenceBlockVariant.preview ? null : (_) {},
              ),
            ),
          ),
        WidgetbookUseCase(
          name: 'locked',
          builder: (context) => Stage(
            child: SentenceBlock(
              variant: SentenceBlockVariant.body,
              text: _sample,
              locked: true,
              onOpenLocked: () {},
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'term-token',
      useCases: [
        for (final variant in TermTokenVariant.values)
          WidgetbookUseCase(
            name: variant.name,
            builder: (context) => Stage(
              child: TermToken(label: '식신', variant: variant, onTap: () {}),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'depth-link',
      useCases: [
        for (final variant in DepthLinkVariant.values)
          WidgetbookUseCase(
            name: variant.id,
            builder: (context) => Stage(
              child: DepthLink(
                variant: variant,
                label: variant == DepthLinkVariant.navigate
                    ? '계산 기준 보기'
                    : '근거 보기',
                onTap: () {},
              ),
            ),
          ),
        for (final state in DepthLinkState.values)
          WidgetbookUseCase(
            name: '근거 시트 ${state.name}',
            builder: (context) => Stage(
              child: SizedBox(
                height: 640,
                child: EvidenceSheetBody(
                  state: state,
                  title: '식신',
                  basis: state == DepthLinkState.unlocked
                      ? _line('일간을 돕는 기운이라 용신으로 판정했어요.')
                      : null,
                  source: state == DepthLinkState.unlocked
                      ? _line('食神制殺, 福壽綿長.')
                      : null,
                  onWatchAd: () {},
                  onPass: () {},
                ),
              ),
            ),
          ),
        WidgetbookUseCase(
          name: '근거 시트 다시 받는 중(loading)',
          builder: (context) => Stage(
            child: SizedBox(
              height: 640,
              child: EvidenceSheetBody(
                state: DepthLinkState.unlocking,
                title: '오늘 풀이의 근거',
                loading: true,
                onWatchAd: () {},
                onPass: () {},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '근거 시트 unlocked, 본문 없음(A22)',
          builder: (context) => const Stage(
            child: SizedBox(
              height: 640,
              child: EvidenceSheetBody(
                state: DepthLinkState.unlocked,
                title: '오늘 풀이의 근거',
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'explain-sheet 내용',
      useCases: [
        WidgetbookUseCase(
          name: '뜻·이유 있음',
          builder: (context) => Stage(
            child: SizedBox(
              height: 300,
              child: ExplainSheetBody(
                title: '식신',
                meaning: _line('내가 낳은 것을 표현하는 기운이에요.'),
                todayReason: _line('오늘은 월지와 닿아 말문이 트이기 쉬워요.'),
                onEvidence: () {},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '제목만(뜻·이유는 계약에 없음)',
          builder: (context) => Stage(
            child: SizedBox(
              height: 300,
              child: ExplainSheetBody(title: '식신', onEvidence: () {}),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '근거 보기 없음(그날 시트에서 열었을 때)',
          builder: (context) => Stage(
            child: SizedBox(
              height: 300,
              child: ExplainSheetBody(
                title: '식신',
                meaning: _line('내가 낳은 것을 표현하는 기운이에요.'),
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'reaction-button',
      useCases: [
        WidgetbookUseCase(
          name: '눌러서 켜고 끄기',
          builder: (context) => Stage(child: _ReactionDemo()),
        ),
      ],
    ),
  ],
);

class _ReactionDemo extends StatefulWidget {
  @override
  State<_ReactionDemo> createState() => _ReactionDemoState();
}

class _ReactionDemoState extends State<_ReactionDemo> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => ReactionButton(
    on: _on,
    onChanged: (value) => setState(() => _on = value),
    semanticsLabel: '이 문장 좋아요',
  );
}
