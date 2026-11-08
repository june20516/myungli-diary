import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/me/application/luck_years.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';

import 'package:myungli_diary/features/me/presentation/chart_text.dart';

import 'package:myungli_diary/features/me/presentation/natal_card.dart';

/// "원국" 탭: 원국표(`saju-pillars`) → 오행 분포(`ohaeng-bar`) → 용신 판정 근거(A57).
class SajuChartNatalTab extends ConsumerWidget {
  /// [chart]의 원국 탭을 만듭니다.
  const new({required this.chart, super.key});

  /// 나의 사주.
  final Chart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ChartText(
      context,
      ref.watch(glossaryProvider).value,
      ref.read(depthSheetsProvider),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NatalCard(chart: chart, onTermTap: text.openTerm),
        _YongsinBasis(chart: chart, text: text),
      ],
    );
  }
}

/// 용신 판정 근거 줄(`saju-chart.yongsin.basis`, `sentence-block` `body`).
///
/// 열렸으면 문장이고 그 안 용어는 풀이 시트(→ 이 슬롯의 근거)를 엽니다. 잠겼으면 흐린 한 줄과
/// "열기"이고, 누르면 근거 시트가 잠긴 채 열려 잠금 해제 흐름(A26)으로 이어집니다(D60). 잠금이
/// 풀리면 차트를 다시 받아 이 줄이 문장으로 바뀝니다. 열렸는데 문장이 없으면(원고 없음) 줄을
/// 그리지 않습니다.
class _YongsinBasis extends StatelessWidget {
  const new({required this.chart, required this.text});

  final Chart chart;
  final ChartText text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final locked = chart.evidenceAccess != EvidenceAccess.unlocked;
    final basis = chart.yongsin.basis?.text;
    if (!locked && (basis == null || isBlankText(basis))) {
      return const SizedBox.shrink();
    }
    final sheets = text.sheets;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 잠겼을 때는 잠긴 줄의 라벨("용신 판정 근거, 잠김")이 이름을 읽으므로 두 번 읽지 않습니다.
          ExcludeSemantics(
            excluding: locked,
            child: Semantics(
              identifier: SlotIds.sajuChartYongsinTitle,
              header: true,
              child: Text(
                text.l10n.sajuChartYongsinTitle,
                style: tokens.typography.subtitle.copyWith(
                  color: tokens.colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s8),
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: basis ?? RenderedText(segments: const []),
            locked: locked,
            slotId: SlotIds.sajuChartYongsinBasis,
            onTerm: (termId) => sheets.openExplain(
              context,
              ExplainTerm(
                termId,
                origin: const TermOrigin(
                  slotId: SlotIds.sajuChartYongsinBasis,
                  subject: ChartEvidenceSubject(),
                ),
              ),
            ),
            onOpenLocked: () =>
                sheets.openEvidence(context, SlotIds.sajuChartYongsinBasis),
          ),
        ],
      ),
    );
  }
}

/// "만세력과 대운" 탭: 만세력 표(`manse-table`) → 대운·세운 표(`daeun-table`, A57).
///
/// 지금 대운과 올해 세운은 기기 오늘([todayProvider]) 기준이라 해가 바뀌면 새 해를 따릅니다
/// (Review Focus 4). 대운 시작 연도는 계약 `DaeunPeriod.startYear`입니다.
class SajuChartLuckTab extends ConsumerWidget {
  /// [chart]의 만세력 탭을 만듭니다.
  const new({required this.chart, super.key});

  /// 나의 사주.
  final Chart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ChartText(
      context,
      ref.watch(glossaryProvider).value,
      ref.read(depthSheetsProvider),
    );
    final l10n = text.l10n;
    final thisYear = ref.watch(todayProvider).year;
    final currentDaeun = currentDaeunIndex(chart.daeun, thisYear: thisYear);
    final periods = chart.daeun.periods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManseTable(
          hour: _manseColumn(text, ChartColumn.hour),
          day: _manseColumn(text, ChartColumn.day),
          month: _manseColumn(text, ChartColumn.month),
          year: _manseColumn(text, ChartColumn.year),
          hiddenStemsHeader: LuckLabel(l10n.manseRowHiddenStems),
          twelveStageHeader: LuckLabel(l10n.manseRowTwelveStages),
          shinsalHeader: LuckLabel(l10n.manseRowShinsal),
          tableLabel: l10n.manseTableLabel,
        ),
        if (periods.isNotEmpty) ...[
          const SizedBox(height: Space.s32),
          DaeunTable(
            daeun: [
              for (final (index, period) in periods.indexed)
                DaeunPillar(
                  age: period.startAgeKorean,
                  startYear: period.startYear,
                  stem: _mini(period.pillar.stem),
                  branch: _miniBranch(period.pillar.branch),
                  ageSemanticLabel: l10n.daeunTableLabel(period.startAgeKorean),
                  semanticLabel: text.join([
                    text.stemText(period.pillar.stem),
                    text.branchText(period.pillar.branch),
                  ]),
                  yearSemanticLabel: l10n.luckYearLabel(period.startYear),
                  stemLabel: text.luckLabel(
                    'ten_god',
                    period.stemTenGod.value,
                    PersonalReadingKey(
                      kind: PersonalReadingKindEnum
                          .PersonalReadingKindDaeunStemTenGod,
                      index: index,
                    ),
                  ),
                  branchLabel: text.luckLabel(
                    'ten_god',
                    period.branchTenGod.value,
                    PersonalReadingKey(
                      kind: PersonalReadingKindEnum
                          .PersonalReadingKindDaeunBranchTenGod,
                      index: index,
                    ),
                  ),
                  stageLabel: text.luckLabel(
                    'twelve_stage',
                    period.twelveStage.value,
                    PersonalReadingKey(
                      kind: PersonalReadingKindEnum
                          .PersonalReadingKindDaeunTwelveStage,
                      index: index,
                    ),
                  ),
                ),
            ],
            seun: [
              for (final (index, year) in chart.seun.indexed)
                SeunYear(
                  year: year.year,
                  stem: _mini(year.pillar.stem),
                  branch: _miniBranch(year.pillar.branch),
                  yearSemanticLabel: l10n.luckYearLabel(year.year),
                  semanticLabel: text.join([
                    text.stemText(year.pillar.stem),
                    text.branchText(year.pillar.branch),
                  ]),
                  label: text.luckLabel(
                    'ten_god',
                    year.tenGod.value,
                    PersonalReadingKey(
                      kind:
                          PersonalReadingKindEnum.PersonalReadingKindSeunTenGod,
                      index: index,
                    ),
                  ),
                ),
            ],
            currentIndex: currentDaeun,
            thisYear: thisYear,
            nowLabel: l10n.daeunTagNow,
            thisYearLabel: l10n.seunTagThisYear,
            tableLabel: l10n.daeunTableLabel(periods.first.startAgeKorean),
          ),
        ],
      ],
    );
  }

  ManseColumn _manseColumn(ChartText text, ChartColumn column) {
    final header = column.header(text.l10n);
    final pillar = column.of(chart);
    if (pillar == null) {
      return ManseColumn(header: header);
    }
    final positions = {column.stem, column.branch};
    final hidden = chart.hiddenStems
        .where((item) => item.position == column.branch)
        .expand((item) => item.stems);
    final stage = chart.twelveStages
        .where((item) => item.position == column.branch)
        .firstOrNull
        ?.stage;
    return ManseColumn(
      header: header,
      stem: _mini(pillar.stem),
      branch: _miniBranch(pillar.branch),
      // 계약 순서(0이 정기) 그대로이고, 개인 해석의 `index`도 이 순서입니다.
      hiddenStems: [
        for (final (index, item) in hidden.indexed)
          ManseHiddenStem(
            hanja: stemHanja(item.stem),
            reading: text.stemReading(item.stem),
            label: text.termLabel(
              'ten_god',
              item.tenGod.value,
              PersonalReadingKey(
                kind: PersonalReadingKindEnum.PersonalReadingKindHiddenTenGod,
                position: column.branch,
                index: index,
              ),
            ),
          ),
      ],
      twelveStage: stage == null
          ? null
          : text.termValue(
              'twelve_stage',
              stage.value,
              PersonalReadingKey(
                kind: PersonalReadingKindEnum.PersonalReadingKindTwelveStage,
                position: column.branch,
              ),
            ),
      shinsal: [
        // 신살은 열린 enum이라 이 app이 모르는 신살은 그 칸에서 건너뜁니다(A66).
        for (final item in chart.shinsal)
          if (item.kind.isKnown && positions.contains(item.position))
            ?text.termValue(
              'shinsal',
              item.kind.value,
              PersonalReadingKey(
                kind: PersonalReadingKindEnum.PersonalReadingKindShinsal,
                position: item.position,
                shinsal: item.kind,
              ),
            ),
      ],
    );
  }

  static OhaengCell _mini(Stem stem) => OhaengCell(
    element: stemElement(stem),
    hanja: stemHanja(stem),
    size: OhaengCellSize.mini,
  );

  static OhaengCell _miniBranch(Branch branch) => OhaengCell(
    element: branchElement(branch),
    hanja: branchHanja(branch),
    size: OhaengCellSize.mini,
  );
}
