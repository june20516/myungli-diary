import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/depth/weighing_note.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 풀이 시트 제목 크기. 기본은 `type.subtitle`이고, 용어 풀이(`term-token`)는 용어 이름이 시트의
/// 주인공이라 `type.title`로 덮어씁니다(계약 `term-token.parts.explainSheet.title`).
enum ExplainTitleSize {
  /// `type.subtitle`(`explain-sheet` 기본).
  subtitle,

  /// `type.title`(`term-token` 풀이 시트).
  title,
}

/// 풀이 시트의 내용(`explain-sheet`). 시트 틀(`sheet` `half`) 안에 놓습니다.
///
/// 제목(또는 [head])과 한자 → 본문(`sentence-block` `body`) 또는 빈 안내([emptyNote]) →
/// 흉 신살 마무리 한 줄([weighingNote]) → 오늘 그런 이유 → [attachment](`stage-strip` 등) →
/// 근거 진입점 아이콘 → 일기 모아보기 링크 순서입니다. 제목 아래 `space.8`에 본문이 오고, [onEvidence]가 null이면
/// 근거 진입점을 그리지 않습니다(그날 시트처럼 근거 시트로 이어지지 않는 곳에서 열었을 때).
/// [onDiaryLink]가 null이면 모아보기 링크를 그리지 않습니다(대표 태그의 뜻 시트에만 있습니다).
///
/// 한자는 제목 줄 끝에 붙고, 그 줄에 다 들어가지 않으면 통째로 다음 줄로 갑니다. 스크린리더는
/// 제목과 한자를 한 덩어리로 읽습니다. 오늘 그런 이유는 오늘 화면에서 열었을 때만 있습니다.
/// [hanja]·[meaning]·[todayReason]은 계약 draft.4의 값이고, 사전·원고에 없어 `null`(한자는 빈
/// 글자도)이면 그 자리를 그리지 않습니다(A22 남은 규칙). 나의 사주·일기 태그 화면도 같은 시트
/// 본문을 씁니다.
class ExplainSheetBody extends StatelessWidget {
  /// 풀이 시트 내용을 만듭니다.
  const new({
    required this.title,
    this.titleSize = ExplainTitleSize.subtitle,
    this.head,
    this.hanja,
    this.onEvidence,
    this.evidenceSubject,
    this.meaning,
    this.meaningSlotId = SlotIds.explainSheetTermMeaning,
    this.emptyNote,
    this.weighingNote,
    this.todayReason,
    this.attachment,
    this.attachmentGap = Space.s12,
    this.diaryLinkLabel,
    this.onDiaryLink,
    super.key,
  });

  /// 명세 대조용 요약. 열림과 닫힘(`sheet.enter`, `sheet.exit`)은 이 본문을 담는 시트 틀
  /// (`sheet` `half`, `DepthSheets.openExplain`)이 그립니다.
  static const ComponentSpec spec = ComponentSpec('explain-sheet', {}, {
    'opening',
    'closing',
  });

  /// 제목 줄의 한자를 찾는 테스트용 키. IA 슬롯이 아닌 컴포넌트 안쪽 키입니다
  /// (IA에 한자 자리 id가 없음).
  static const Key hanjaKey = ValueKey('explain-sheet-hanja');

  /// 제목 아래 본문까지의 간격. 계약 `explain-sheet.parts.title.marginBottom`(`space.8`).
  static const double titleGap = Space.s8;

  /// 일기 모아보기 링크 위 간격. 계약 `explain-sheet.parts.diaryLink.marginTop`(`space.16`).
  static const double diaryLinkGap = Space.s16;

  /// 제목(과 한자) 아래 빈 안내까지. 계약 `term-token.parts.explainSheet.emptyNote.marginTop`
  /// (`space.12`).
  static const double emptyNoteGap = Space.s12;

  /// 빈 안내 줄 수(`emptyNote.maxLines`). 배율 1.0에서 원고 글자 수 상한을 잰 줄 수이고, 큰
  /// 글자에서는 자르지 않고 줄이 늡니다(A137 ④와 같은 읽기, A139).
  static const int emptyNoteMaxLines = 2;

  /// 빈 안내를 찾는 테스트용 키(IA 밖 슬롯 `ui.explain.term-empty`).
  static const Key emptyNoteKey = ValueKey('explain-sheet-empty-note');

  /// 시트 제목(누른 항목의 이름).
  final String title;

  /// 제목 크기(기본 `type.subtitle`, 용어 풀이는 `type.title`).
  final ExplainTitleSize titleSize;

  /// 제목 줄 대신 놓을 머리(`hanja-tag`). 있으면 제목 글자와 한자는 그리지 않습니다.
  final Widget? head;

  /// 용어 한자(`type.caption.md`, `text.secondary`, 글꼴 `font.family.hanja`).
  /// 사전에 없으면 `null`입니다.
  final String? hanja;

  /// 본문(용어 뜻, ui 문장, 행운 칩 설명). 없으면 `null`입니다.
  final RenderedText? meaning;

  /// [meaning]이 그리는 IA 슬롯 id. 용어 뜻이 아니면 null로 줍니다.
  final String? meaningSlotId;

  /// 뜻도 오늘 그런 이유도 근거 출처도 없는 용어의 빈 안내(`term-token` `explainSheet.emptyNote`,
  /// V123). 있으면 뜻 자리(제목 아래 [emptyNoteGap])에 두고 근거 진입점은 그리지 않습니다.
  final String? emptyNote;

  /// 뜻 바로 아래 흉 신살 마무리 한 줄([WeighingNote], D124 ⑦, V120). 대상 신살의 용어 풀이만
  /// 주고, 뜻([meaning])이 없거나 빈 문장이면 그리지 않습니다. 다음 문장 간격은 이 상자에서 셉니다.
  final String? weighingNote;

  /// 오늘 그런 이유(`explain-sheet.today.reason`). 오늘 화면에서 열지 않았거나 계약에 없으면 `null`입니다.
  final RenderedText? todayReason;

  /// 본문 아래 [attachmentGap]에 붙일 위젯(`stage-strip`, 시간 시트의 `timeBand` 등).
  final Widget? attachment;

  /// 위 문장과 [attachment] 사이. 기본은 `space.12`이고 시간 시트의 24시간 띠는 `space.20`입니다
  /// (`lucky-card` `timeBand.when`).
  final double attachmentGap;

  /// 근거 진입점을 눌렀을 때(근거 시트 열기). null이면 진입점이 없습니다.
  final VoidCallback? onEvidence;

  /// 근거 진입점의 스크린리더 항목 이름. null이면 [title]입니다.
  final String? evidenceSubject;

  /// 일기 모아보기 링크 글자(`explainSheetTagDiaryLink`). 꺾쇠는 컴포넌트가 붙입니다.
  final String? diaryLinkLabel;

  /// 일기 모아보기 링크를 눌렀을 때(시트를 닫고 `tag-diary` page.push). null이면 링크가 없습니다.
  final VoidCallback? onDiaryLink;

  /// 불러오는 중 뼈: 제목 자리(글줄 한 줄, [titleSize]의 글자) 또는 이미 아는 [head]를 그대로,
  /// [titleGap] 아래 본문 `sentence-block` `body` 뼈. 화면 배치는 시트 본문과 같습니다(V66).
  static Widget skeleton({
    Widget? head,
    ExplainTitleSize titleSize = ExplainTitleSize.subtitle,
  }) => Builder(
    builder: (context) {
      final typography = context.tokens.typography;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 제목 자리와 같은 여백(SheetHeading 위 space.8)만 둡니다. SheetHeading은 시트의 첫
          // 초점을 가져가므로 뼈에 쓰면 내용이 온 뒤 실제 제목이 초점을 받지 못합니다.
          Padding(
            padding: const EdgeInsets.only(top: Space.s8),
            child: head == null
                ? SkeletonTextLines(
                    style: switch (titleSize) {
                      ExplainTitleSize.subtitle => typography.subtitle,
                      ExplainTitleSize.title => typography.title,
                    },
                  )
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: head,
                  ),
          ),
          const SizedBox(height: titleGap),
          SentenceBlock.skeleton(variant: SentenceBlockVariant.body, index: 1),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final meaning = this.meaning;
    final todayReason = this.todayReason;
    final weighingNote = this.weighingNote;
    final emptyNote = this.emptyNote;
    final attachment = this.attachment;
    final onEvidence = this.onEvidence;
    final diaryLinkLabel = this.diaryLinkLabel;
    final onDiaryLink = this.onDiaryLink;
    final head = this.head;
    // 제목 바로 아래 첫 문장만 titleGap이고, 그다음 문장은 12입니다.
    var first = true;
    double gap() {
      final value = first ? titleGap : Space.s12;
      first = false;
      return value;
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeading(
            child: head == null
                ? _titleLine(tokens)
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: head,
                  ),
          ),
          if (emptyNote != null)
            Padding(
              padding: const EdgeInsets.only(top: emptyNoteGap),
              child: Text(
                emptyNote,
                key: emptyNoteKey,
                style: tokens.typography.bodyUi.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
            ),
          if (meaning != null)
            Padding(
              padding: EdgeInsets.only(top: gap()),
              child: SentenceBlock(
                variant: SentenceBlockVariant.body,
                text: meaning,
                slotId: meaningSlotId,
              ),
            ),
          // 뜻이 없으면 상자도 두지 않습니다. 빈 문장 뜻은 여는 쪽이 없는 것으로 넘깁니다(A139 ②).
          if (meaning != null && weighingNote != null)
            WeighingNote(text: weighingNote),
          if (todayReason != null)
            Padding(
              padding: EdgeInsets.only(top: gap()),
              child: SentenceBlock(
                variant: SentenceBlockVariant.body,
                text: todayReason,
                slotId: SlotIds.explainSheetTodayReason,
              ),
            ),
          if (attachment != null)
            Padding(
              padding: EdgeInsets.only(top: attachmentGap),
              child: attachment,
            ),
          // 빈 안내가 있으면 근거 진입점 아이콘만 남기지 않습니다(V123).
          if (onEvidence != null && emptyNote == null)
            DepthLink.evidence(
              subject: evidenceSubject ?? title,
              onTap: onEvidence,
            ),
          if (diaryLinkLabel != null && onDiaryLink != null)
            DepthLink(
              variant: DepthLinkVariant.navigate,
              label: diaryLinkLabel,
              onTap: onDiaryLink,
              marginTop: diaryLinkGap,
            ),
        ],
      ),
    );
  }

  /// 제목 줄. 한자가 있으면 같은 줄 끝에 두고, 줄이 모자라면 한자만 다음 줄로 보냅니다.
  Widget _titleLine(MyungliTokens tokens) {
    final titleText = Text(
      title,
      style: switch (titleSize) {
        ExplainTitleSize.subtitle => tokens.typography.subtitle,
        ExplainTitleSize.title => tokens.typography.title,
      }.copyWith(color: tokens.colors.textPrimary),
    );
    final hanja = this.hanja;
    if (hanja == null || hanja.isEmpty) {
      return titleText;
    }
    return Semantics(
      label: '$title $hanja',
      excludeSemantics: true,
      child: Wrap(
        spacing: Space.s8,
        // 글자 크기가 달라도 아래 선을 맞춰 같은 줄로 읽히게 합니다.
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          titleText,
          Text(
            hanja,
            key: hanjaKey,
            // 크기·굵기·행간은 caption.md 그대로 두고 글꼴만 한자 family(`font.family.hanja`,
            // 원국표 한자 `type.hanja.pillar`와 같은 family)로 바꿉니다. 문장 글꼴에는 한자
            // 글리프가 없습니다.
            style: tokens.typography.captionMd.copyWith(
              color: tokens.colors.textSecondary,
              fontFamily: tokens.typography.hanjaPillar.fontFamily,
              fontFamilyFallback:
                  tokens.typography.hanjaPillar.fontFamilyFallback,
            ),
          ),
        ],
      ),
    );
  }
}
