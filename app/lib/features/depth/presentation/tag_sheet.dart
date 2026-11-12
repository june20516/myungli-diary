import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/weighing_note.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/tag_sentence_list.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/weighing_shinsal.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// 사주 기운 시트(`tag-sheet`, D108, 결정 V79) 본문. [daily]의 대표 태그 [rank]순위를 보입니다.
///
/// 위에서부터 머리(누를 수 없는 `hanja-tag` + 오른쪽 끝 근거 아이콘) → `space.12`
/// 뜻(사전 `tag.<key>`) → (흉 신살 태그면 마무리 한 줄, V120) → `space.24`
/// "이 기운에서 나온 오늘 문장"(`tag-sentence-list`)
/// → 그 태그가 붙은 내 일기 보기 링크입니다(today.md "tag-sheet 화면 배치").
///
/// 문장 줄과 근거는 A113을 따릅니다: 1순위(`featured[0]`)는 보조 문장(`fortune.tag`)과 오늘의
/// 질문(`guide`) 줄이고 머리 근거 아이콘은 보조 문장의 근거 시트를 엽니다(머리 태그와 보조 문장을
/// 대상으로). 2순위는 그 태그 몫의 문장과 근거가 계약에 없어 빈 안내(IA `empty`)이고 근거 아이콘이
/// 없습니다. 비었거나 없는 문장은 줄을 두지 않고, 사전에 뜻이 없으면 뜻 자리를 그리지 않습니다
/// (A22 남은 규칙).
///
/// 이 시트는 오늘 화면이 사전으로 그린 대표 태그에서만 열립니다. 그래서 사전은 이미 받아 둔
/// 상태이고, 받지 못했거나 그 태그를 그릴 수 없으면(사전, 글자표에 없음) 아무것도 그리지 않습니다.
/// [rank]가 응답의 대표 태그 범위 밖이어도 그리지 않습니다.
class TagSheet extends ConsumerWidget {
  /// [daily]의 [rank]순위 대표 태그 시트를 만듭니다.
  const new({required this.daily, required this.rank, super.key});

  /// 머리와 뜻 사이(`tag-sheet` 배치 2번).
  static const double meaningGap = Space.s12;

  /// 뜻(또는 머리)과 문장 목록 사이(`tag-sheet` 배치 3번).
  static const double sentencesGap = Space.s24;

  /// 그날 오늘 응답.
  final Daily daily;

  /// 누른 대표 태그의 `tags.featured` 순번(0이 1순위).
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(glossaryProvider).value;
    final featured = daily.tags.featured;
    // 범위 밖 순번(응답이 바뀐 뒤 열린 시트 등)은 그리지 않습니다.
    final inRange = rank >= 0 && rank < featured.length;
    final tag = names == null || !inRange
        ? null
        : featuredTagContentOf(featured[rank], rank, names);
    if (names == null || tag == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final meaning = names.meaningOf('tag.${tag.key}');
    final fortuneTag = _nonBlank(daily.fortune.tag);
    final guide = _nonBlank(daily.guide);
    final first = rank == 0;
    HanjaTag headTag() => HanjaTag(glyph: tag.glyph, label: tag.label);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SheetHeading(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: headTag(),
                  ),
                ),
              ),
              if (first && fortuneTag != null)
                // SheetHeading의 위 여백과 같은 자리에서 태그와 가운데를 맞춥니다.
                Padding(
                  padding: const EdgeInsets.only(top: SheetHeading.topGap),
                  child: DepthLink.evidence(
                    subject: tag.label,
                    placement: DepthLinkPlacement.inlineEnd,
                    onTap: () => unawaited(
                      ref
                          .read(depthSheetsProvider)
                          .openEvidence(
                            context,
                            fortuneTag.slot,
                            headTags: [headTag()],
                            target: fortuneTag.text,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          if (meaning != null && !isBlankText(meaning))
            Padding(
              padding: const EdgeInsets.only(top: meaningGap),
              child: SentenceBlock(
                variant: SentenceBlockVariant.body,
                text: meaning,
                slotId: SlotIds.tagSheetTagMeaning,
                termStyle: TermStyle.plain,
              ),
            ),
          // 흉 신살 태그면 뜻 바로 아래 마무리 한 줄(V120). 다음 구역 간격은 상자에서 셉니다.
          if (meaning != null &&
              !isBlankText(meaning) &&
              isWeighingKey(tag.key))
            WeighingNote(text: l10n.shinsalWeighingNote),
          Padding(
            padding: const EdgeInsets.only(top: sentencesGap),
            child: TagSentenceList(
              title: l10n.tagSheetSentencesTitle,
              items: [
                if (first && fortuneTag != null)
                  TagSentence(
                    kindLabel: l10n.tagSheetSentenceKindFortune,
                    text: fortuneTag.text,
                  ),
                if (first && guide != null)
                  TagSentence(
                    kindLabel: l10n.tagSheetSentenceKindGuide,
                    text: guide.text,
                  ),
              ],
              emptyText: l10n.tagSheetSentencesEmpty,
              diaryLinkLabel: l10n.tagSheetDiaryCta(tag.label),
              onDiaryLink: () => _openTagDiary(context, tag.key),
            ),
          ),
        ],
      ),
    );
  }

  /// [text]가 있고 비어 있지 않으면 그대로, 아니면 null입니다.
  static SlotText? _nonBlank(SlotText? text) =>
      text == null || isBlankText(text.text) ? null : text;

  /// 시트를 닫고 [tag] 모아보기로 page.push 합니다. 닫은 뒤에는 이 context를 쓸 수 없어서
  /// 라우터를 먼저 잡아 둡니다.
  static void _openTagDiary(BuildContext context, String tag) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push<void>(taggedPathOf(tag)));
  }
}
