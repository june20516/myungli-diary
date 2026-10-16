import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 풀이 시트의 내용(`explain-sheet`). 시트 틀(`sheet` `half`) 안에 놓습니다.
///
/// 제목·한자 → 용어 뜻 → 오늘 그런 이유 → 근거 보기 링크 순서입니다. [onEvidence]가 null이면
/// 근거 링크를 그리지 않습니다(그날 시트처럼 근거 시트로 이어지지 않는 곳에서 열었을 때).
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
    this.hanja,
    this.onEvidence,
    this.meaning,
    this.todayReason,
    super.key,
  });

  /// 제목 줄의 한자를 찾는 테스트용 키.
  static const Key hanjaKey = ValueKey('explain-sheet.title.hanja');

  /// 시트 제목(용어 이름, `type.title`).
  final String title;

  /// 용어 한자(`type.caption.md`, `text.secondary`). 사전에 없으면 `null`입니다.
  final String? hanja;

  /// 용어 뜻(`explain-sheet.term.meaning`). 계약에 없으면 `null`입니다.
  final RenderedText? meaning;

  /// 오늘 그런 이유(`explain-sheet.today.reason`). 오늘 화면에서 열지 않았거나 계약에 없으면 `null`입니다.
  final RenderedText? todayReason;

  /// "근거 보기"를 눌렀을 때(근거 시트 열기). null이면 근거 링크가 없습니다.
  final VoidCallback? onEvidence;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final meaning = this.meaning;
    final todayReason = this.todayReason;
    final onEvidence = this.onEvidence;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeading(child: _titleLine(tokens)),
          if (meaning != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.s12),
              child: SentenceBlock(
                variant: SentenceBlockVariant.body,
                text: meaning,
                slotId: SlotIds.explainSheetTermMeaning,
              ),
            ),
          if (todayReason != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.s12),
              child: SentenceBlock(
                variant: SentenceBlockVariant.body,
                text: todayReason,
                slotId: SlotIds.explainSheetTodayReason,
              ),
            ),
          if (onEvidence != null)
            DepthLink(
              variant: DepthLinkVariant.block,
              label: AppLocalizations.of(context).depthLinkEvidence,
              onTap: onEvidence,
            ),
        ],
      ),
    );
  }

  /// 제목 줄. 한자가 있으면 같은 줄 끝에 두고, 줄이 모자라면 한자만 다음 줄로 보냅니다.
  Widget _titleLine(MyungliTokens tokens) {
    final titleText = Text(
      title,
      style: tokens.typography.title.copyWith(color: tokens.colors.textPrimary),
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
            style: tokens.typography.captionMd.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
