import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';

import 'package:myungli_diary/features/me/presentation/chart_text.dart';

/// 사주 원국 카드: 원국표(`saju-pillars`)와 오행 분포(`ohaeng-bar`)(A57).
///
/// 나 탭 "사주 원국"과 사주 표 원국 탭이 함께 씁니다. 칸의 용어를 누르면 [onTermTap]이 불립니다.
class NatalCard extends ConsumerWidget {
  /// [chart]의 원국 카드를 만듭니다.
  const new({required this.chart, required this.onTermTap, super.key});

  /// 나의 사주.
  final Chart chart;

  /// 칸의 용어를 눌렀을 때.
  final TermTapHandler onTermTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ChartText(
      context,
      ref.watch(glossaryProvider).value,
      ref.read(depthSheetsProvider),
      onTermTap: onTermTap,
    );
    final l10n = text.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SajuPillars(
          hour: _pillarColumn(text, ChartColumn.hour),
          day: _pillarColumn(text, ChartColumn.day),
          month: _pillarColumn(text, ChartColumn.month),
          year: _pillarColumn(text, ChartColumn.year),
          meLabel: l10n.sajuTagMe,
          tableLabel: l10n.sajuPillarsTableLabel,
        ),
        const SizedBox(height: Space.s24),
        _ohaengBar(text),
      ],
    );
  }

  SajuPillarColumn _pillarColumn(ChartText text, ChartColumn column) {
    final header = column.header(text.l10n);
    final pillar = column.of(chart);
    if (pillar == null) {
      return SajuPillarColumn(header: header, semanticLabel: header);
    }
    final dayMaster = column == ChartColumn.day;
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
  Widget _dayMasterLabel(ChartText text, Stem stem) {
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
  Widget _ohaengBar(ChartText text) {
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
