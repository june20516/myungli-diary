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
/// `body`) → 아래 `space.24`에 점수 항목 표 [ScoreRow.rule] 일곱 줄(줄 사이
/// `list.divider`)입니다
/// (A116: 일곱 줄은 [ScoreItemMeta.rule] 상수, 점수 0 제외). 항목 이름은 용어 사전
/// `score_item`이고, 사전에 이름이 없거나 한자 글자표에 없는 줄은 그리지 않고 비치명으로 한 번만
/// 기록합니다(A112). 사전을 받기 전(로딩, 오류)에는 표 자리에 보이지 않는 일곱 줄을 두어
/// 높이를 지킵니다(계약은 뼈가 없음). 시트는 달력 화면 뒤에서 사전이 이미 로드된 채 열리는
/// 경우가 대부분이라 이 자리는 드뭅니다. 사전 오류는 사전 쪽 기존 경로가 보고합니다.
/// 출구가 없고 태그는 누를 수 없습니다. 내용이 넘치면 시트 안에서 스크롤합니다.
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
    final rows = <Widget>[];
    final gaps = <String>[];
    for (final rule in ScoreItemMeta.rule) {
      if (names == null) {
        rows.add(_placeholderRow(rule.score));
        continue;
      }
      final name = names.valueName(ScoreItemMeta.glossaryCategory, rule.id);
      final glyph = HanjaGlyphs.forScoreItem(rule.id);
      if (name == null || glyph == null) {
        // 사전을 받은 뒤의 빈칸입니다(받기 전은 위에서 자리만 지킴).
        gaps.add('${ScoreItemMeta.glossaryCategory}.${rule.id}');
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

  /// 사전을 받기 전 자리 지킴 줄: 그리지도 읽지도 않고 높이만 차지합니다.
  Widget _placeholderRow(int score) => Visibility(
    visible: false,
    maintainSize: true,
    maintainAnimation: true,
    maintainState: true,
    child: ExcludeSemantics(
      child: ScoreRow.rule(glyph: '合', name: '합', score: score),
    ),
  );

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
