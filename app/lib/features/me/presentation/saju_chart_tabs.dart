import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/me/application/luck_years.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';

/// 원국표의 기둥 한 열과 그 천간·지지 자리.
enum _Column {
  hour(Position.hourStem, Position.hourBranch),
  day(Position.dayStem, Position.dayBranch),
  month(Position.monthStem, Position.monthBranch),
  year(Position.yearStem, Position.yearBranch);

  new(this.stem, this.branch);

  /// 천간 자리.
  final Position stem;

  /// 지지 자리.
  final Position branch;

  /// [chart]의 이 기둥. 시간 모름의 시주는 null입니다.
  Pillar? of(Chart chart) => switch (this) {
    _Column.hour => chart.pillars.hour,
    _Column.day => chart.pillars.day,
    _Column.month => chart.pillars.month,
    _Column.year => chart.pillars.year,
  };

  /// 열 머리(시주·일주·월주·연주).
  String header(AppLocalizations l10n) => switch (this) {
    _Column.hour => l10n.sajuPillarHour,
    _Column.day => l10n.sajuPillarDay,
    _Column.month => l10n.sajuPillarMonth,
    _Column.year => l10n.sajuPillarYear,
  };
}

/// 사주 표 칸의 글자(A65)와 용어 토큰을 만듭니다.
///
/// 한자·오행은 간지 표, 독음·용어 이름은 용어 사전 `values`에서 읽습니다. 이름이 없으면 사전
/// 한자, 그것도 없으면 그 자리를 비웁니다(키를 그대로 보이지 않음). 용어 토큰은 이름이 있을 때만
/// 누를 수 있고, 누르면 풀이 시트를 엽니다. 그 풀이 시트의 "근거 보기"는 누른 칸의 원국 개인
/// 해석을 보이는 근거 시트입니다(A58).
final class _ChartText {
  const new(this.context, this.names, this.sheets);

  final BuildContext context;
  final GlossaryNames? names;
  final DepthSheets sheets;

  AppLocalizations get l10n => AppLocalizations.of(context);

  /// [category]의 [value] 이름. 없으면 사전 한자, 그것도 없으면 null입니다.
  String? nameOf(String category, String value) =>
      names?.valueName(category, value) ?? names?.hanjaOf('$category.$value');

  String? stemReading(Stem stem) => names?.valueName('stem', stem.value);

  String? branchReading(Branch branch) =>
      names?.valueName('branch', branch.value);

  String? elementName(FiveElement element) => nameOf('element', element.value);

  /// "庚 경"처럼 한자와 독음(있으면).
  String stemText(Stem stem) => [stemHanja(stem), ?stemReading(stem)].join(' ');

  String branchText(Branch branch) =>
      [branchHanja(branch), ?branchReading(branch)].join(' ');

  /// 표 칸 용어의 풀이 시트를 엽니다.
  void openTerm(String termId, PersonalReadingKey personal) =>
      sheets.openExplain(
        context,
        termId: termId,
        origin: TermOrigin(
          // 표 칸은 writing 슬롯이 아니라, 열릴 근거 시트의 "내 사주에서는" 슬롯을 가리킵니다.
          slotId: SlotIds.evidenceSheetPersonalBody,
          subject: const ChartEvidenceSubject(),
          personal: personal,
        ),
      );

  /// [category].[value] 용어의 `label` 토큰. 이름이 없으면 한자 글자, 그것도 없으면 null입니다.
  Widget? termLabel(
    String category,
    String value,
    PersonalReadingKey personal,
  ) {
    final name = names?.valueName(category, value);
    if (name != null) {
      return TermToken(
        label: name,
        variant: TermTokenVariant.label,
        onTap: () => openTerm('$category.$value', personal),
      );
    }
    final hanja = names?.hanjaOf('$category.$value');
    return hanja == null ? null : plainLabel(hanja);
  }

  /// 대운·세운 표의 [category].[value] 라벨(V49). 이름이 없으면 누를 수 없는 한자 글자,
  /// 그것도 없으면 null(자리만 남김)입니다.
  LuckLabel? luckLabel(
    String category,
    String value,
    PersonalReadingKey personal,
  ) {
    final name = names?.valueName(category, value);
    if (name != null) {
      return LuckLabel(
        name,
        onTap: () => openTerm('$category.$value', personal),
      );
    }
    final hanja = names?.hanjaOf('$category.$value');
    return hanja == null ? null : LuckLabel(hanja);
  }

  /// 표 값 칸(12운성·신살)의 용어. 글자는 표가 주는 값 글자를 따릅니다(`term-token` `inline`).
  /// 이름이 없으면 한자 글자, 그것도 없으면 null입니다.
  Widget? termValue(
    String category,
    String value,
    PersonalReadingKey personal,
  ) {
    final name = names?.valueName(category, value);
    if (name != null) {
      return TermToken(
        label: name,
        variant: TermTokenVariant.inline,
        onTap: () => openTerm('$category.$value', personal),
      );
    }
    final hanja = names?.hanjaOf('$category.$value');
    return hanja == null ? null : Text(hanja);
  }

  /// 누를 수 없는 라벨 글자(`term-token` `label`과 같은 크기).
  Widget plainLabel(String text) {
    final tokens = context.tokens;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tokens.typography.captionMd.copyWith(
        color: tokens.colors.textSecondary,
      ),
    );
  }

  /// 스크린리더 항목을 잇습니다.
  String join(Iterable<String?> parts) => parts.nonNulls
      .where((part) => part.isNotEmpty)
      .join(l10n.a11yListSeparator);
}

/// "원국" 탭: 원국표(`saju-pillars`) → 오행 분포(`ohaeng-bar`) → 용신 판정 근거(A57).
class SajuChartNatalTab extends ConsumerWidget {
  /// [chart]의 원국 탭을 만듭니다.
  const new({required this.chart, super.key});

  /// 나의 사주.
  final Chart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = _ChartText(
      context,
      ref.watch(glossaryProvider).value,
      ref.read(depthSheetsProvider),
    );
    final l10n = text.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SajuPillars(
          hour: _pillarColumn(text, _Column.hour),
          day: _pillarColumn(text, _Column.day),
          month: _pillarColumn(text, _Column.month),
          year: _pillarColumn(text, _Column.year),
          meLabel: l10n.sajuTagMe,
          tableLabel: l10n.sajuPillarsTableLabel,
        ),
        const SizedBox(height: Space.s24),
        _ohaengBar(text),
        _YongsinBasis(chart: chart, text: text),
      ],
    );
  }

  SajuPillarColumn _pillarColumn(_ChartText text, _Column column) {
    final header = column.header(text.l10n);
    final pillar = column.of(chart);
    if (pillar == null) {
      return SajuPillarColumn(header: header, semanticLabel: header);
    }
    final dayMaster = column == _Column.day;
    final stemGod = dayMaster ? null : _tenGodAt(column.stem);
    final branchGod = _tenGodAt(column.branch);
    final stemElementOf = stemElement(pillar.stem);
    final branchElementOf = branchElement(pillar.branch);
    return SajuPillarColumn(
      header: header,
      semanticLabel: text.join([
        header,
        text.stemText(pillar.stem),
        text.elementName(stemElementOf),
        if (dayMaster)
          text.l10n.sajuPillarDayMaster
        else if (stemGod != null)
          text.nameOf('ten_god', stemGod),
        text.branchText(pillar.branch),
        text.elementName(branchElementOf),
        if (branchGod != null) text.nameOf('ten_god', branchGod),
      ]),
      stem: OhaengCell(
        element: stemElementOf,
        hanja: stemHanja(pillar.stem),
        reading: text.stemReading(pillar.stem),
      ),
      branch: OhaengCell(
        element: branchElementOf,
        hanja: branchHanja(pillar.branch),
        reading: text.branchReading(pillar.branch),
      ),
      stemLabel: dayMaster
          ? _dayMasterLabel(text, pillar.stem)
          : stemGod == null
          ? null
          : text.termLabel(
              'ten_god',
              stemGod,
              PersonalReadingKey(
                kind: PersonalReadingKindEnum.PersonalReadingKindTenGod,
                position: column.stem,
              ),
            ),
      branchLabel: branchGod == null
          ? null
          : text.termLabel(
              'ten_god',
              branchGod,
              PersonalReadingKey(
                kind: PersonalReadingKindEnum.PersonalReadingKindTenGod,
                position: column.branch,
              ),
            ),
    );
  }

  /// 일간 라벨. 누르면 일간(그 천간)의 풀이이고, 근거 시트는 일간 개인 해석입니다.
  Widget _dayMasterLabel(_ChartText text, Stem stem) {
    final label = text.l10n.sajuPillarDayMaster;
    if (text.names?.nameOf('stem.${stem.value}') == null) {
      return text.plainLabel(label);
    }
    return TermToken(
      label: label,
      variant: TermTokenVariant.label,
      onTap: () => text.openTerm(
        'stem.${stem.value}',
        const PersonalReadingKey(
          kind: PersonalReadingKindEnum.PersonalReadingKindDayMaster,
          position: Position.dayStem,
        ),
      ),
    );
  }

  /// [position]의 십성 값(지지는 정기 기준). 없으면 null입니다.
  String? _tenGodAt(Position position) {
    for (final item in chart.tenGods) {
      if (item.position == position) return item.tenGod.value;
    }
    return null;
  }

  /// 오행 분포: 목·화·토·금·수 순서, 값은 소수 한 자리(A57).
  Widget _ohaengBar(_ChartText text) {
    final weights = {
      for (final item in chart.elementWeights) item.element: item.weight,
    };
    final items = [
      for (final element in FiveElement.values)
        OhaengBarItem(
          element: element,
          name: text.elementName(element) ?? '',
          value: (weights[element] ?? 0).toDouble(),
          count: (weights[element] ?? 0).toStringAsFixed(1),
        ),
    ];
    return OhaengBar(
      items: items,
      semanticLabel: [
        for (final item in items)
          text.l10n.ohaengBarItem(item.name, item.count),
      ].join(text.l10n.a11yListSeparator),
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
  final _ChartText text;

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
              termId: termId,
              origin: const TermOrigin(
                slotId: SlotIds.sajuChartYongsinBasis,
                subject: ChartEvidenceSubject(),
              ),
            ),
            onOpenLocked: () => sheets.openEvidence(
              context,
              slotId: SlotIds.sajuChartYongsinBasis,
            ),
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
    final text = _ChartText(
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
          hour: _manseColumn(text, _Column.hour),
          day: _manseColumn(text, _Column.day),
          month: _manseColumn(text, _Column.month),
          year: _manseColumn(text, _Column.year),
          hiddenStemsHeader: text.plainLabel(l10n.manseRowHiddenStems),
          twelveStageHeader: text.plainLabel(l10n.manseRowTwelveStages),
          shinsalHeader: text.plainLabel(l10n.manseRowShinsal),
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

  ManseColumn _manseColumn(_ChartText text, _Column column) {
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
