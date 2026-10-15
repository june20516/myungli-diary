import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show WidgetTester;
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

RenderedText _text(List<Segment> segments) => RenderedText(segments: segments);

final RenderedText _siksin = _text([
  Segment(text: '오늘은 '),
  Segment(text: '식신', term: 'TenGod.SIKSIN'),
  Segment(text: '의 기운이 강해서 마음에 담아 둔 말을 꺼내기 좋은 날이에요. 천천히 '),
  Segment(text: '정관', term: 'TenGod.JEONGGWAN'),
  Segment(text: '처럼 단정하게 하루를 시작해 보세요.'),
]);

final RenderedText _siksinJa = _text([
  Segment(text: '今日は'),
  Segment(text: '食神', term: 'TenGod.SIKSIN'),
  Segment(text: 'の気が強く、心に秘めた言葉を伝えるのにふさわしい日です。ゆっくりと'),
  Segment(text: '正官', term: 'TenGod.JEONGGWAN'),
  Segment(text: 'のように端正に一日を始めてみましょう。'),
]);

Widget _sentenceBlocks() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final text = ja ? _siksinJa : _siksin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        SentenceBlock(
          variant: SentenceBlockVariant.card,
          text: text,
          termStyle: TermStyle.chip,
          onTerm: (_) {},
        ),
        SentenceBlock(
          variant: SentenceBlockVariant.body,
          text: text,
          termStyle: TermStyle.chip,
          onTerm: (_) {},
        ),
        SentenceBlock(
          variant: SentenceBlockVariant.body,
          text: text,
          trailing: DepthLink(
            variant: DepthLinkVariant.inlineEnd,
            label: ja ? '根拠を見る' : '근거 보기',
            onTap: () {},
          ),
        ),
        SentenceBlock(variant: SentenceBlockVariant.preview, text: text),
        SentenceBlock(
          variant: SentenceBlockVariant.body,
          text: text,
          locked: true,
          onOpenLocked: () {},
        ),
      ],
    );
  },
);

Widget _termsAndLinks() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: Space.s12,
  children: [
    TermToken(
      label: '식신',
      variant: TermTokenVariant.inline,
      onTap: () {},
      textStyle: const TextStyle(fontSize: 15, height: 1.6),
    ),
    TermToken(label: '정관', variant: TermTokenVariant.label, onTap: () {}),
    DepthLink(variant: DepthLinkVariant.block, label: '근거 보기', onTap: () {}),
  ],
);

const double _bodyHeight = 700;

Widget _evidence(DepthLinkState state, {bool loading = false}) {
  final unlocked = state == DepthLinkState.unlocked;
  return SizedBox(
    height: _bodyHeight,
    // 시트 안쪽 여백(space.20)을 흉내 냅니다.
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s20),
      child: EvidenceSheetBody(
        state: state,
        title: '식신',
        pillars: const SizedBox(height: 40),
        basis: unlocked
            ? _text([Segment(text: '일간을 돕는 기운이라 용신으로 판정했어요.')])
            : null,
        source: unlocked ? _text([Segment(text: '食神制殺, 福壽綿長.')]) : null,
        personal: unlocked
            ? _text([Segment(text: '내 사주에서는 월지에 있어 힘이 커요.')])
            : null,
        showPersonal: true,
        loading: loading,
        onWatchAd: () {},
        onPass: () {},
        animated: false,
      ),
    ),
  );
}

/// 풀이 시트 내용: 뜻·이유가 있을 때와 계약에 없어 자리가 없을 때.
Widget _explain({required bool withText}) => SizedBox(
  height: 420,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.s20),
    child: ExplainSheetBody(
      title: '식신',
      meaning: withText ? _text([Segment(text: '내가 낳은 것을 표현하는 기운이에요.')]) : null,
      todayReason: withText
          ? _text([Segment(text: '오늘은 월지와 닿아 말문이 트이기 쉬워요.')])
          : null,
      onEvidence: () {},
    ),
  ),
);

Widget _reactions() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    ReactionButton(on: false, onChanged: (_) {}, semanticsLabel: '좋아요'),
    ReactionButton(on: true, onChanged: (_) {}, semanticsLabel: '좋아요'),
  ],
);

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  goldenTest('sentence-block: card·body·preview·inline-end·locked', (
    tester,
  ) async {
    await goldenMatrix(
      tester,
      'sentence_block',
      _sentenceBlocks,
      settle: _settle,
    );
  });

  goldenTest('term-token·depth-link', (tester) async {
    await goldenMatrix(tester, 'sentence_term_depth_link', _termsAndLinks);
  });

  for (final state in DepthLinkState.values) {
    goldenTest('depth-link evidenceSheet: ${state.name}', (tester) async {
      await goldenMatrix(
        tester,
        'sentence_evidence_${state.name}',
        () => _evidence(state),
        settle: _settle,
      );
    });
  }

  goldenTest('depth-link evidenceSheet: 다시 받는 중(loading)', (tester) async {
    await goldenMatrix(
      tester,
      'sentence_evidence_loading',
      () => _evidence(DepthLinkState.unlocking, loading: true),
      settle: _settle,
    );
  });

  for (final withText in [true, false]) {
    goldenTest('explain-sheet 내용: ${withText ? '뜻·이유 있음' : '뜻·이유 없음'}', (
      tester,
    ) async {
      await goldenMatrix(
        tester,
        'sentence_explain_${withText ? 'full' : 'title_only'}',
        () => _explain(withText: withText),
        settle: _settle,
      );
    });
  }

  goldenTest('reaction-button: off·on', (tester) async {
    await goldenMatrix(
      tester,
      'sentence_reaction',
      _reactions,
      settle: _settle,
    );
  });
}
