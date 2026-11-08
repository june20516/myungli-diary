import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/model/score_item_meta.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';

/// 이미 보고한 점수 항목 사전 빈칸(용어 id). 시트를 다시 그려도 같은 빈칸을 거듭 보고하지
/// 않게 앱 실행 동안 한 번만 보고합니다(A112).
final _reportedScoreItemGapsProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

/// 색 규칙 시트(`color-rule-sheet`, V87) 본문.
///
/// 위에서부터 제목(`type.subtitle`, 핸들 자리 아래 `space.8`) → 설명 문장(`sentence-block`
/// `body`) → 아래 `space.24`에 점수 항목 표 [ScoreRow.rule] 일곱 줄(줄 사이 `list.divider`)입니다
/// (A116: 일곱 줄은 [ScoreItemMeta.rule] 상수, 점수 0 제외). 항목 이름은 용어 사전
/// `score_item`이고, 사전에 이름이 없거나 한자 글자표에 없는 줄은 그리지 않고 비치명으로 한 번만
/// 기록합니다(A112). 출구가 없고 태그는 누를 수 없습니다. 내용이 넘치면 시트 안에서 스크롤합니다.
class ColorRuleSheet extends ConsumerWidget {
  /// 색 규칙 시트 본문을 만듭니다.
  const new({super.key});

  /// 설명 문장과 표 사이(`color-rule-sheet` 배치 3번).
  static const double tableGap = Space.s24;

  /// 제목 글자를 찾는 테스트용 키.
  static const Key titleKey = ValueKey('color-rule-sheet-title');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final names = ref.watch(glossaryProvider).value;
    final rows = <ScoreRow>[];
    final gaps = <String>[];
    for (final rule in ScoreItemMeta.rule) {
      final name = names?.valueName(ScoreItemMeta.glossaryCategory, rule.id);
      final glyph = HanjaGlyphs.forScoreItem(rule.id);
      if (name == null || glyph == null) {
        // 사전을 받은 뒤에만 빈칸으로 셉니다(받기 전에는 모든 항목이 이름이 없어 보임).
        if (names != null) {
          gaps.add('${ScoreItemMeta.glossaryCategory}.${rule.id}');
        }
        continue;
      }
      rows.add(ScoreRow.rule(glyph: glyph, name: name, score: rule.score));
    }
    if (gaps.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _reportGaps(ref, gaps);
      });
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeading(
            child: Text(
              l10n.colorRuleSheetSheetTitle,
              key: titleKey,
              style: tokens.typography.subtitle.copyWith(
                color: tokens.colors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.s12),
            child: SentenceBlock(
              variant: SentenceBlockVariant.body,
              text: RenderedText(
                segments: [Segment(text: l10n.colorRuleSheetRuleBody)],
              ),
              slotId: SlotIds.colorRuleSheetRuleBody,
            ),
          ),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: tableGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const ListDivider(),
                    rows[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _reportGaps(WidgetRef ref, List<String> termIds) {
    final reported = ref.read(_reportedScoreItemGapsProvider);
    for (final termId in termIds) {
      if (!reported.add(termId)) continue;
      ref
          .read(crashReporterProvider)
          .record(
            CrashSummary.from(MissingDictionaryEntry(termId)),
            StackTrace.current,
          );
    }
  }
}
