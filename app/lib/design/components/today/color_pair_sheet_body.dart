import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/elements/ohaeng_swatch.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 색이 둘인 날 행운 색 시트의 색 하나(`lucky-card` `colorPairSheet.section`).
@immutable
final class ColorPairSection {
  /// 색 하나의 구역을 만듭니다. [onEvidence]가 null이면 근거 진입점을 그리지 않습니다.
  const new({
    required this.element,
    required this.name,
    required this.body,
    required this.bodySlotId,
    required this.onEvidence,
  });

  /// 견본 색의 오행(`ohaeng.swatch` 14).
  final FiveElement element;

  /// 색 이름(`type.label.lg`, `text.primary`). 근거 진입점의 항목 이름이기도 합니다.
  final String name;

  /// 그 색 카드의 풀이 문장(`sentence-block` `body`).
  final RenderedText body;

  /// [body]가 채우는 IA 슬롯(`colorPairSheet.sections[].bodySlot`).
  final String bodySlotId;

  /// 그 색의 근거 진입점을 눌렀을 때(근거 시트 열기, D123 ②).
  final VoidCallback? onEvidence;
}

/// 색이 둘인 날 행운 색 시트 본문(`lucky-card` `colorPairSheet`, D119 ②, D123 ①②,
/// V114, V118).
///
/// 제목(항목 이름) → [intro](추천 색이 둘이라는 한 줄, `caption.lg` `text.secondary`) → 색마다 구역
/// (견본과 이름, 풀이 문장, 그 색의 근거 진입점)이 `list.divider`를 사이에 두고 첫째 색, 둘째 색
/// 순서로 이어집니다. 기준 이름 부제목(내 균형 기준, 원전 기준)은 두지 않습니다(`basisLabel` false).
/// 시트 틀(`sheet` `half`) 안에 놓습니다.
class ColorPairSheetBody extends StatelessWidget {
  /// 두 색 시트 본문을 만듭니다.
  const new({
    required this.title,
    required this.intro,
    required this.sections,
    super.key,
  });

  /// 한 줄 안내 아래 첫 구역까지(`intro.gapBelow` {space.12}).
  static const double introGapBelow = Space.s12;

  /// 견본과 색 이름 사이(`section.head.gap` {space.4}).
  static const double headGap = Space.s4;

  /// 머리 아래 풀이 문장까지(`section.body.gapAbove` {space.8}).
  static const double bodyGapAbove = Space.s8;

  /// 구역 사이 구분선 위아래 간격(`between.gap` {space.16}).
  static const double betweenGap = Space.s16;

  /// [index]째 구역(0이 첫째 색)을 찾는 테스트용 키.
  static Key sectionKey(int index) => ValueKey('color-pair-section-$index');

  /// 구역 사이 구분선을 찾는 테스트용 키.
  static const Key dividerKey = ValueKey('color-pair-divider');

  /// 시트 제목(항목 이름 "행운 색").
  final String title;

  /// 맨 위 한 줄(`today.lucky-color.pair.intro`).
  final String intro;

  /// 색마다 구역(첫째 색, 둘째 색 순서).
  final List<ColorPairSection> sections;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final typography = tokens.typography;
    final colors = tokens.colors;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeading(
            child: Text(
              title,
              style: typography.subtitle.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: ExplainSheetBody.titleGap),
          Text(
            intro,
            key: const ValueKey(SlotIds.todayLuckyColorPairIntro),
            style: typography.captionLg.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: introGapBelow),
          for (final (index, section) in sections.indexed) ...[
            if (index > 0) ...[
              const SizedBox(height: betweenGap),
              // 구역에는 좌우 여백이 없어 선도 들이지 않습니다(A135).
              const ListDivider(key: dividerKey, indentStart: 0, indentEnd: 0),
              const SizedBox(height: betweenGap),
            ],
            _Section(key: sectionKey(index), section: section),
          ],
        ],
      ),
    );
  }
}

/// 색 하나의 구역: 머리(견본과 이름), 풀이 문장, 근거 진입점.
class _Section extends StatelessWidget {
  const new({required this.section, super.key});

  final ColorPairSection section;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final onEvidence = section.onEvidence;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: ColorPairSheetBody.headGap,
          children: [
            OhaengSwatch(
              element: section.element,
              size: OhaengSwatch.luckySize,
            ),
            Flexible(
              child: Text(
                section.name,
                style: tokens.typography.labelLg.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ColorPairSheetBody.bodyGapAbove),
        // 누를 곳이 없어 용어 조각은 누를 수 없는 일반 글자로 그립니다(onTerm 없음).
        SentenceBlock(
          variant: SentenceBlockVariant.body,
          text: section.body,
          slotId: section.bodySlotId,
        ),
        if (onEvidence != null)
          DepthLink.evidence(subject: section.name, onTap: onEvidence),
      ],
    );
  }
}
