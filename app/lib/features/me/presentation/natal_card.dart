import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
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

/// 일간 칩이 여는 용어 id(writing W61).
const String dayMasterTermId = 'role.day_master';

/// 사주 원국 카드: 원국표(`saju-pillars`)와 오행 분포(`ohaeng-bar`)(A57).
///
/// 나 탭 "사주 원국"은 둘을 한 카드에 함께([NatalCard.new]), 사주 표 원국 탭은 섹션 머리를
/// 사이에 두고 따로([NatalCard.pillars], [NatalCard.ohaeng]) 씁니다. 칸의 용어를 누르면
/// [onTermTap]이 불립니다.
class NatalCard extends ConsumerWidget {
  /// [chart]의 원국표와 오행 분포를 함께 그립니다.
  const new({required this.chart, required this.onTermTap, super.key})
    : _part = _NatalPart.both;

  /// [chart]의 원국표만 그립니다.
  const new pillars({required this.chart, required this.onTermTap, super.key})
    : _part = _NatalPart.pillars;

  /// [chart]의 오행 분포만 그립니다.
  const new ohaeng({required this.chart, super.key})
    : onTermTap = _noTermTap,
      _part = _NatalPart.ohaeng;

  /// 나의 사주.
  final Chart chart;

  /// 칸의 용어를 눌렀을 때.
  final TermTapHandler onTermTap;

  final _NatalPart _part;

  static void _noTermTap(String termId, PersonalReadingKey personal) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ChartText(
      context,
      ref.watch(glossaryProvider).value,
      ref.read(depthSheetsProvider),
      onTermTap: onTermTap,
    );
    return switch (_part) {
      _NatalPart.pillars => _pillars(text),
      _NatalPart.ohaeng => _ohaengBar(text),
      _NatalPart.both => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pillars(text),
          const SizedBox(height: Space.s24),
          _ohaengBar(text),
        ],
      ),
    };
  }

  Widget _pillars(ChartText text) => SajuPillars(
    hour: _pillarColumn(text, ChartColumn.hour),
    day: _pillarColumn(text, ChartColumn.day),
    month: _pillarColumn(text, ChartColumn.month),
    year: _pillarColumn(text, ChartColumn.year),
    meLabel: text.l10n.sajuTagMe,
    tableLabel: text.l10n.sajuPillarsTableLabel,
  );

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
          ? _dayMasterLabel(text)
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

  /// 일간 라벨. 누르면 용어 "일간"(`role.day_master`, W61, F-019)의 풀이이고, 그 "근거 보기"는
  /// 일간 개인 해석입니다. 사전에 그 용어 이름이 없으면 누를 수 없는 글자입니다.
  Widget _dayMasterLabel(ChartText text) {
    final label = text.l10n.sajuPillarDayMaster;
    if (text.names?.nameOf(dayMasterTermId) == null) {
      return text.plainLabel(label);
    }
    return TermToken(
      label: label,
      variant: TermTokenVariant.label,
      onTap: () => text.openTerm(
        dayMasterTermId,
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

/// [NatalCard]가 그리는 부분.
enum _NatalPart { both, pillars, ohaeng }
