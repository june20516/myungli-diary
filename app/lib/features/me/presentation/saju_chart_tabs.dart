import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/section_card.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/stage_strip.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/me/application/luck_years.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';
import 'package:myungli_diary/features/me/presentation/chart_text.dart';
import 'package:myungli_diary/features/me/presentation/natal_card.dart';

/// "원국" 탭: 사주(`saju-pillars`) → 오행 분포(`ohaeng-bar`) → 용신 판정 근거(A57, V88).
///
/// 섹션마다 `section-header`이고 사주와 오행 분포는 제목 아래 한 줄 설명을 늘 보입니다. 표와
/// 막대는 흰 카드에 놓입니다. 원국 "신강" 알약은 그리지 않습니다(D113 ⑦).
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
    final l10n = text.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.sajuChartPillarsTitle,
          description: l10n.sajuChartPillarsDesc,
          titleIdentifier: SlotIds.sajuChartPillarsTitle,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        SectionCard(
          child: NatalCard.pillars(chart: chart, onTermTap: text.openTerm),
        ),
        const SizedBox(height: SectionHeader.sectionGap),
        SectionHeader(
          title: l10n.sajuChartOhaengTitle,
          description: l10n.sajuChartOhaengDesc,
          titleIdentifier: SlotIds.sajuChartOhaengTitle,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        SectionCard(child: NatalCard.ohaeng(chart: chart)),
        _YongsinBasis(chart: chart, text: text),
      ],
    );
  }
}

/// 용신 판정 근거 섹션(`saju-chart.yongsin.basis`, `sentence-block` `body`, 흰 카드).
///
/// 열렸으면 문장이고 그 안 용어는 풀이 시트(→ 이 슬롯의 근거)를 엽니다. 잠겼으면 앞부분
/// (`Yongsin.basisPreview`, 없으면 자리값만)과 흐린 자리값 두 줄, 오른쪽 자물쇠 "열기"이고, 누르면
/// 근거 시트가 잠긴 채 열려 잠금 해제 흐름(A26)으로 이어집니다(D60, D106). 잠금이 풀리면 차트를
/// 다시 받아 문장으로 바뀌고, 열린 문장에는 `unlock.glint`가 지나갑니다(`sentence-block`
/// `unlocked`, D118 ②). 열렸는데 문장이 없으면(원고 없음) 섹션을 그리지 않습니다.
class _YongsinBasis extends StatelessWidget {
  const new({required this.chart, required this.text});

  final Chart chart;
  final ChartText text;

  @override
  Widget build(BuildContext context) {
    final locked = chart.evidenceAccess != EvidenceAccess.unlocked;
    final basis = chart.yongsin.basis?.text;
    if (!locked && (basis == null || isBlankText(basis))) {
      return const SizedBox.shrink();
    }
    final sheets = text.sheets;
    return Padding(
      padding: const EdgeInsets.only(top: SectionHeader.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 잠겼을 때는 잠긴 줄의 라벨("용신 판정 근거, 앞부분, 잠김")이 이름을 읽으므로 두 번
          // 읽지 않습니다.
          ExcludeSemantics(
            excluding: locked,
            child: SectionHeader(
              title: text.l10n.sajuChartYongsinTitle,
              titleIdentifier: SlotIds.sajuChartYongsinTitle,
            ),
          ),
          const SizedBox(height: SectionHeader.contentGap),
          SectionCard(
            child: SentenceBlock(
              variant: SentenceBlockVariant.body,
              text: basis ?? RenderedText(segments: const []),
              locked: locked,
              // 열려서 보이게 된 판정 근거는 반짝입니다(D118 ②).
              unlocked: !locked,
              lockedLead: chart.yongsin.basisPreview,
              slotId: SlotIds.sajuChartYongsinBasis,
              // 이 문장이 곧 판정 근거라(server가 근거 목록을 주지 않음) 용어 시트에서 다시 근거로
              // 잇지 않습니다(A129, #931).
              onTerm: (termId) =>
                  sheets.openExplain(context, ExplainTerm(termId)),
              onOpenLocked: () =>
                  sheets.openEvidence(context, SlotIds.sajuChartYongsinBasis),
            ),
          ),
        ],
      ),
    );
  }
}

/// "만세력과 대운" 탭: 만세력 표(`manse-table`) → 대운과 세운 줄(`daeun-table`, A57, V89, V90).
///
/// 지금 대운과 올해 세운은 기기 오늘([todayProvider]) 기준이라 해가 바뀌면 새 해를 따릅니다
/// (Review Focus 4). 대운 시작 연도는 계약 `DaeunPeriod.startYear`입니다. 띠 머리 칩(지장간,
/// 12운성, 신살)은 설명 시트를 열고, 12운성 시트만 본문 아래 `stage-strip`이 붙습니다(V91).
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
        _manseTable(context, text),
        if (periods.isNotEmpty || chart.seun.isNotEmpty) ...[
          const SizedBox(height: SectionHeader.sectionGap),
          DaeunTable(
            daeun: [
              for (final (index, period) in periods.indexed)
                DaeunPillar(
                  age: period.startAgeKorean,
                  startYear: period.startYear,
                  pillar: luckGanjiOf(period.pillar),
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
                  pillar: luckGanjiOf(year.pillar),
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
            daeunTitle: l10n.sajuChartDaeunTitle,
            daeunDescription: l10n.sajuChartDaeunDesc,
            seunTitle: l10n.sajuChartSeunTitle,
            seunDescription: l10n.sajuChartSeunDesc,
          ),
        ],
      ],
    );
  }

  /// 만세력 표: 기준 줄 "내 일간 庚(경금) 기준" + 띠 표.
  Widget _manseTable(BuildContext context, ChartText text) {
    final l10n = text.l10n;
    final dayStem = chart.pillars.day.stem;
    final glyph = stemHanja(dayStem);
    return ManseTable(
      basis: l10n.sajuChartManseBasis(dayMasterText(text, dayStem)),
      basisGlyph: glyph,
      table: BandTable(
        columns: [
          for (final column in ChartColumn.values) _bandColumn(text, column),
        ],
        bandLabels: _bandLabels(l10n),
        onBandTap: (kind) => unawaited(_openBand(context, text, kind)),
        meLabel: l10n.sajuTagMe,
        emptyLabel: l10n.bandTableEmptyCell,
        tableLabel: l10n.manseTableLabel,
      ),
    );
  }

  static Map<BandKind, String> _bandLabels(AppLocalizations l10n) => {
    BandKind.hiddenStems: l10n.manseRowHiddenStems,
    BandKind.twelveStages: l10n.manseRowTwelveStages,
    BandKind.shinsal: l10n.manseRowShinsal,
  };

  /// 띠 머리 칩 [kind]의 설명 시트. 12운성만 본문 아래 내 네 자리의 `stage-strip`입니다.
  Future<void> _openBand(BuildContext context, ChartText text, BandKind kind) {
    final l10n = text.l10n;
    final title = _bandLabels(l10n)[kind]!;
    final content = switch (kind) {
      BandKind.hiddenStems => ExplainUiText(
        title: title,
        body: l10n.sajuChartJijangganDesc,
      ),
      BandKind.twelveStages => ExplainUiText(
        title: title,
        body: l10n.sajuChartUnseongDesc,
        attachment: _stageStrip(text),
      ),
      BandKind.shinsal => ExplainUiText(
        title: title,
        body: l10n.sajuChartSinsalDesc,
      ),
    };
    return text.sheets.openExplain(context, content);
  }

  /// 내 네 자리(시간 모름이면 시주 없음)의 12운성 띠.
  StageStrip _stageStrip(ChartText text) {
    TwelveStage? stageAt(Position branch) => chart.twelveStages
        .where((item) => item.position == branch)
        .firstOrNull
        ?.stage;
    final positions = <PillarPosition, TwelveStage>{
      for (final (position, column) in [
        (PillarPosition.hour, ChartColumn.hour),
        (PillarPosition.day, ChartColumn.day),
        (PillarPosition.month, ChartColumn.month),
        (PillarPosition.year, ChartColumn.year),
      ])
        if (column.of(chart) != null) position: ?stageAt(column.branch),
    };
    return StageStrip(
      positions: positions,
      stageNames: {
        for (final stage in StageStrip.order)
          stage: ?text.nameOf('twelve_stage', stage.value),
      },
    );
  }

  BandColumn _bandColumn(ChartText text, ChartColumn column) {
    final header = column.header(text.l10n);
    final isDay = column == ChartColumn.day;
    if (column.of(chart) == null) {
      return BandColumn(header: header, isDay: isDay, empty: true);
    }
    final positions = {column.stem, column.branch};
    final hidden = chart.hiddenStems
        .where((item) => item.position == column.branch)
        .expand((item) => item.stems);
    final stage = chart.twelveStages
        .where((item) => item.position == column.branch)
        .firstOrNull
        ?.stage;
    return BandColumn(
      header: header,
      isDay: isDay,
      // 계약 순서(0이 정기) 그대로이고, 개인 해석의 `index`도 이 순서입니다.
      hiddenStems: [
        for (final (index, item) in hidden.indexed)
          BandHiddenStem(
            element: stemElement(item.stem),
            hanja: stemHanja(item.stem),
            semanticLabel: text.stemText(item.stem),
            tenGod: text.luckLabel(
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
          : text.luckLabel(
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
            ?text.luckLabel(
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
}

/// 간지 [pillar]를 `luck-pillar` 입력으로 바꿉니다.
LuckGanji luckGanjiOf(Pillar pillar) => LuckGanji(
  stemElement: stemElement(pillar.stem),
  stemHanja: stemHanja(pillar.stem),
  branchElement: branchElement(pillar.branch),
  branchHanja: branchHanja(pillar.branch),
);

/// 일간 표기 "庚(경금)": 한자 뒤 괄호에 독음과 오행 이름. 독음이 없으면 한자만, 오행 이름이
/// 없으면 독음까지입니다.
String dayMasterText(ChartText text, Stem stem) {
  final glyph = stemHanja(stem);
  final reading = text.stemReading(stem);
  if (reading == null) return glyph;
  final element = text.names?.valueName('element', stemElement(stem).value);
  return '$glyph($reading${element ?? ''})';
}
