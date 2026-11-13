import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show WidgetTester;
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
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
          trailing: DepthLink.evidence(
            subject: ja ? '総運' : '총운',
            placement: DepthLinkPlacement.inlineEnd,
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
    DepthLink.evidence(
      subject: '총운',
      placement: DepthLinkPlacement.headEnd,
      onTap: () {},
    ),
    DepthLink(
      variant: DepthLinkVariant.navigate,
      label: '계산 기준 보기',
      onTap: () {},
    ),
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
        // 근거가 둘이면 구역마다 문단 둘을 space.12 간격으로 쌓습니다(A42).
        basis: [
          if (unlocked) ...[
            _text([Segment(text: '일간을 돕는 오행이 부족해 그 오행을 용신으로 봤어요.')]),
            _text([Segment(text: '일간을 돕는 기운이라 용신으로 판정했어요.')]),
          ],
        ],
        // 원전은 상자 없이 뜻, 원문, 출처 줄 묶음입니다(V113).
        source: [
          if (unlocked) ...[
            _text([
              Segment(text: '식신이 살을 다스리면 복과 수명이 길다는 뜻이에요.\n'),
              Segment(text: '食神制殺, 福壽綿長.\n원전 「대목」'),
            ]),
            _text([
              Segment(text: '오행마다 바른 빛깔이 있다는 뜻이에요.\n'),
              Segment(text: '推其形色，則水黑、火赤、木青、土黄，此正色也。\n원전 「대목」'),
            ]),
          ],
        ],
        // 열리면 제목 옆 꼬리표(D118 ①). 반짝임은 박자가 끝난 뒤(띠 없음)를 찍습니다.
        unlockTag: unlocked
            ? AppLocalizationsKo().evidenceSheetUnlockUntilMidnight
            : null,
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

/// 풀이 시트 내용: 뜻·이유가 있을 때와 없어서 자리가 없을 때. [evidence]가 false면
/// 근거 보기 링크가 없습니다(그날 시트에서 열었을 때). [hanja]는 제목 줄 끝의 용어 한자입니다.
Widget _explain({
  required bool withText,
  bool evidence = true,
  String? hanja,
}) => SizedBox(
  height: 420,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.s20),
    child: ExplainSheetBody(
      title: '식신',
      hanja: hanja,
      meaning: withText ? _text([Segment(text: '내가 낳은 것을 표현하는 기운이에요.')]) : null,
      todayReason: withText
          ? _text([Segment(text: '오늘은 월지와 닿아 말문이 트이기 쉬워요.')])
          : null,
      onEvidence: evidence ? () {} : null,
    ),
  ),
);

/// 괴강 魁罡(D124, 토큰 1.9.0). 罡은 Pretendard JP에 없어 대체 글꼴
/// `Myungli Hanja Supplement`로 그립니다. 魁罡이 보이는 자리는 풀이 시트 제목 옆 한자(모든 언어),
/// ja 용어 칩(사전 이름 `shinsal.goegang` 魁罡), 근거 원전 출처 줄(writing 원고
/// `source.sammyeong-tonghoe/shinsal#goegang`, ja 三命通会「魁罡」)입니다. ko 칩과 출처는 한글입니다.
Widget _hanjaSupplement() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final name = ja ? '魁罡' : '괴강';
    return SizedBox(
      height: 520,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.s12,
          children: [
            TermToken(
              label: name,
              variant: TermTokenVariant.inline,
              onTap: () {},
              textStyle: const TextStyle(fontSize: 15, height: 1.6),
            ),
            TermToken(
              label: name,
              variant: TermTokenVariant.label,
              onTap: () {},
            ),
            ExplainSheetBody(title: name, hanja: '魁罡'),
            Expanded(
              child: EvidenceSheetBody(
                state: DepthLinkState.unlocked,
                title: name,
                source: [
                  _text([
                    Segment(
                      text: ja
                          ? 'この格には庚辰、壬辰、戊戌、庚戌の四つの日があるという意味です。\n'
                                '此格有四日庚辰壬辰戊戌庚戌\n三命通会「魁罡」'
                          : '이 격에는 경진, 임진, 무술, 경술의 네 날이 있다는 뜻이에요.\n'
                                '此格有四日庚辰壬辰戊戌庚戌\n삼명통회 「괴강」',
                    ),
                  ]),
                ],
                animated: false,
              ),
            ),
          ],
        ),
      ),
    );
  },
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
        () => _explain(withText: withText, hanja: withText ? '食神' : null),
        settle: _settle,
      );
    });
  }

  goldenTest('explain-sheet 내용: 근거 보기 없음(그날 시트)', (tester) async {
    await goldenMatrix(
      tester,
      'sentence_explain_no_evidence',
      () => _explain(withText: true, evidence: false),
      settle: _settle,
    );
  });

  goldenTest('괴강 魁罡 대체 글꼴: term-token과 근거 원전(D124, 토큰 1.9.0)', (tester) async {
    await goldenMatrix(
      tester,
      'sentence_hanja_supplement',
      _hanjaSupplement,
      settle: _settle,
    );
  });

  goldenTest('reaction-button: off·on', (tester) async {
    await goldenMatrix(
      tester,
      'sentence_reaction',
      _reactions,
      settle: _settle,
    );
  });
}
