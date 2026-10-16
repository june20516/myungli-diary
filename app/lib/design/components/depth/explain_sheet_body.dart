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
/// 제목 → 용어 뜻 → 오늘 그런 이유 → 근거 보기 링크 순서입니다. 오늘 그런 이유는 오늘 화면에서
/// 열었을 때만 있으므로 [meaning]·[todayReason]은 각각 `null`이어도 됩니다. `null`이면 그
/// 자리를 그리지 않습니다(결정 A22). 계약에 뜻·이유 필드가 들어오면 호출하는 쪽이 값만
/// 넘기며, 나의 사주·일기 태그 화면도 같은 시트 본문을 씁니다.
class ExplainSheetBody extends StatelessWidget {
  /// 풀이 시트 내용을 만듭니다.
  const new({
    required this.title,
    required this.onEvidence,
    this.meaning,
    this.todayReason,
    super.key,
  });

  /// 시트 제목(용어 이름, `type.title`).
  final String title;

  /// 용어 뜻(`explain-sheet.term.meaning`). 계약에 없으면 `null`입니다.
  final RenderedText? meaning;

  /// 오늘 그런 이유(`explain-sheet.today.reason`). 오늘 화면에서 열지 않았거나 계약에 없으면 `null`입니다.
  final RenderedText? todayReason;

  /// "근거 보기"를 눌렀을 때(근거 시트 열기).
  final VoidCallback onEvidence;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final meaning = this.meaning;
    final todayReason = this.todayReason;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeading(
            child: Text(
              title,
              style: tokens.typography.title.copyWith(
                color: tokens.colors.textPrimary,
              ),
            ),
          ),
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
          DepthLink(
            variant: DepthLinkVariant.block,
            label: AppLocalizations.of(context).depthLinkEvidence,
            onTap: onEvidence,
          ),
        ],
      ),
    );
  }
}
