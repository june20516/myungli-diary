import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 대운 기둥 하나.
@immutable
final class DaeunPillar {
  /// [age](한국식 나이)에 시작하는 대운. 낭독 글은 칸마다 따로 받습니다(V49 읽는 순서).
  const new({
    required this.age,
    required this.startYear,
    required this.stem,
    required this.branch,
    required this.ageSemanticLabel,
    required this.semanticLabel,
    this.yearSemanticLabel,
    this.stemLabel,
    this.branchLabel,
    this.stageLabel,
  });

  /// 시작 나이(한국식, core C22).
  final int age;

  /// 시작 연도. 모르면(출생 연도를 모름) null이고 그 줄을 비웁니다.
  final int? startYear;

  /// 천간 `mini` 칸.
  final OhaengCell stem;

  /// 지지 `mini` 칸.
  final OhaengCell branch;

  /// 나이 칸 낭독 글.
  final String ageSemanticLabel;

  /// 간지 칸 낭독 글(천간·지지 한자와 독음).
  final String semanticLabel;

  /// 시작 연도 낭독 글. 연도를 모르면 null입니다.
  final String? yearSemanticLabel;

  /// 천간 위 십성(`term-token` `label`). 없으면 자리만 남깁니다.
  final LuckLabel? stemLabel;

  /// 지지 아래 십성(정기). 없으면 자리만 남깁니다.
  final LuckLabel? branchLabel;

  /// 지지 십성 아래 12운성. 없으면 자리만 남깁니다.
  final LuckLabel? stageLabel;
}

/// 세운(한 해) 칸.
@immutable
final class SeunYear {
  /// [year]의 세운.
  const new({
    required this.year,
    required this.stem,
    required this.branch,
    required this.yearSemanticLabel,
    required this.semanticLabel,
    this.label,
  });

  /// 연도.
  final int year;

  /// 천간 `mini` 칸.
  final OhaengCell stem;

  /// 지지 `mini` 칸.
  final OhaengCell branch;

  /// 연도 칸 낭독 글.
  final String yearSemanticLabel;

  /// 간지 칸 낭독 글(천간·지지 한자와 독음).
  final String semanticLabel;

  /// 천간 위 그 해의 천간 십성(`term-token` `label`). 없으면 자리만 남깁니다.
  final LuckLabel? label;
}

/// 대운·세운 표(`daeun-table`).
///
/// 대운은 가로로 넘기는 기둥 줄(너비 52, 사이 4)이고 기둥마다 위에서부터 한국식 나이 → 천간
/// 십성 → 천간·지지 `ohaeng.cell` `mini` → 지지 십성(정기) → 12운성 → 시작 연도입니다(V49).
/// 세운은 지금 대운 10년을 5열 2줄로 두고 칸마다 천간 위에 그 해 십성 하나입니다. 라벨은
/// [LuckLabelView] 규칙(가운데, 낱말 단위 두 줄, 넘치면 글자 줄임)이고, 없는 기둥도 자리는
/// 남깁니다. 라벨 줄은 기둥(세운은 같은 행 다섯 칸)마다 가장 높은 라벨에 맞춰 간지 칸이 가로로
/// 나란합니다.
///
/// 지금 대운([currentIndex])은 `highlight.current`(바탕 `status.bg`,
/// 나이 `action.primary` 굵게)와 위에 [nowLabel] 꼬리표(`tag.status`)입니다.
/// 올해 세운([thisYear])도 같은 강조와 [thisYearLabel] 꼬리표입니다
/// (`current`·`thisYear`). 낙관 윤곽은 쓰지 않습니다.
///
/// 스크린리더는 기둥마다 나이 → 천간 십성 → 간지 → 지지 십성 → 12운성 → 시작 연도 순서로
/// 읽습니다(세운은 연도 → 십성 → 간지). 처음 열 때 지금 대운이 보이게 가로 위치를 맞춰 두고
/// 움직이지 않습니다. 글자 크기는 1.3배에서 멈춥니다.
class DaeunTable extends StatefulWidget {
  /// 표를 만듭니다. [tableLabel]은 스크린리더 표 이름("대운 N세부터 …")입니다.
  const new({
    required this.daeun,
    required this.seun,
    required this.currentIndex,
    required this.thisYear,
    required this.nowLabel,
    required this.thisYearLabel,
    required this.tableLabel,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('daeun-table', {}, {
    'current',
    'thisYear',
  });

  /// 대운 기둥 너비.
  static const double pillarWidth = 52;

  /// 대운 기둥 사이.
  static const double pillarGap = 4;

  /// 대운 줄을 찾는 테스트용 키.
  static const Key daeunScrollKey = ValueKey('daeun-table-daeun');

  /// [index] 대운 기둥을 찾는 테스트용 키.
  static Key daeunKey(int index) => ValueKey('daeun-table-daeun-$index');

  /// 기둥 안 강조 바탕(`highlight.current`)을 찾는 테스트용 키.
  static const Key highlightKey = ValueKey('daeun-table-highlight');

  /// [year] 세운 칸을 찾는 테스트용 키.
  static Key seunKey(int year) => ValueKey('daeun-table-seun-$year');

  /// 대운 기둥들(나이 순).
  final List<DaeunPillar> daeun;

  /// 지금 대운 10년의 세운.
  final List<SeunYear> seun;

  /// 지금 대운의 자리. 없으면(아직 대운 전 등) null입니다.
  final int? currentIndex;

  /// 올해. 세운 칸 강조에 씁니다.
  final int? thisYear;

  /// '지금' 꼬리표 글자.
  final String nowLabel;

  /// '올해' 꼬리표 글자.
  final String thisYearLabel;

  /// 스크린리더 표 이름.
  final String tableLabel;

  @override
  State<DaeunTable> createState() => _DaeunTableState();
}

class _DaeunTableState extends State<DaeunTable> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  /// 지금 대운이 가운데 오는 처음 위치(넘길 수 있는 범위 안).
  ScrollController _controllerFor(double viewport) {
    final existing = _scroll;
    if (existing != null) return existing;
    const step = DaeunTable.pillarWidth + DaeunTable.pillarGap;
    final count = widget.daeun.length;
    final content = count * step - DaeunTable.pillarGap;
    final index = widget.currentIndex ?? 0;
    final centered = index * step - (viewport - DaeunTable.pillarWidth) / 2;
    final offset = centered.clamp(0, math.max(0, content - viewport));
    return _scroll = ScrollController(initialScrollOffset: offset.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: OhaengCell.textScaleMax);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Semantics(
        container: true,
        label: widget.tableLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const width = DaeunTable.pillarWidth;
                double rowOf(LuckLabel? Function(DaeunPillar) pick) =>
                    _rowHeight(context, widget.daeun.map(pick), width);
                final rows = _LabelRows(
                  above: rowOf((pillar) => pillar.stemLabel),
                  below: rowOf((pillar) => pillar.branchLabel),
                  stage: rowOf((pillar) => pillar.stageLabel),
                );
                return SingleChildScrollView(
                  key: DaeunTable.daeunScrollKey,
                  controller: _controllerFor(constraints.maxWidth),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, pillar) in widget.daeun.indexed) ...[
                        if (index > 0)
                          const SizedBox(width: DaeunTable.pillarGap),
                        _Pillar(
                          key: DaeunTable.daeunKey(index),
                          width: width,
                          rows: rows,
                          top: '${pillar.age}',
                          topSemanticLabel: pillar.ageSemanticLabel,
                          stem: pillar.stem,
                          branch: pillar.branch,
                          bottom: pillar.startYear?.toString() ?? '',
                          bottomSemanticLabel: pillar.yearSemanticLabel,
                          aboveLabel: pillar.stemLabel,
                          belowLabel: pillar.branchLabel,
                          stageLabel: pillar.stageLabel,
                          current: index == widget.currentIndex,
                          currentLabel: widget.nowLabel,
                          semanticLabel: pillar.semanticLabel,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: Space.s16),
            _SeunGrid(
              seun: widget.seun,
              thisYear: widget.thisYear,
              thisYearLabel: widget.thisYearLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// [labels] 가운데 폭 [width] 칸에서 가장 높은 라벨의 높이. 라벨이 하나도 없으면 0입니다.
double _rowHeight(
  BuildContext context,
  Iterable<LuckLabel?> labels,
  double width,
) => labels.fold(
  0,
  (highest, label) => math.max(highest, luckLabelHeight(context, label, width)),
);

/// 기둥 줄(대운) 또는 세운 한 행이 함께 쓰는 라벨 줄 높이. 0이면 그 줄을 두지 않습니다.
@immutable
final class _LabelRows {
  const new({required this.above, this.below = 0, this.stage = 0});

  /// 천간 위 십성 줄.
  final double above;

  /// 지지 아래 십성 줄(대운).
  final double below;

  /// 12운성 줄(대운).
  final double stage;
}

/// 세운 5열 격자(줄은 칸 수에 따라 늘어남, 10년이면 2줄).
class _SeunGrid extends StatelessWidget {
  const new({
    required this.seun,
    required this.thisYear,
    required this.thisYearLabel,
  });

  final List<SeunYear> seun;
  final int? thisYear;
  final String thisYearLabel;

  static const int _columns = 5;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cellWidth =
          (constraints.maxWidth - DaeunTable.pillarGap * (_columns - 1)) /
          _columns;
      final rows = <Widget>[];
      for (var start = 0; start < seun.length; start += _columns) {
        final slice = seun.sublist(
          start,
          math.min(start + _columns, seun.length),
        );
        final labelRows = _LabelRows(
          above: _rowHeight(context, slice.map((y) => y.label), cellWidth),
        );
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _columns; i++) ...[
                if (i > 0) const SizedBox(width: DaeunTable.pillarGap),
                Expanded(
                  child: i < slice.length
                      ? _Pillar(
                          key: DaeunTable.seunKey(slice[i].year),
                          width: cellWidth,
                          rows: labelRows,
                          top: '${slice[i].year}',
                          topSemanticLabel: slice[i].yearSemanticLabel,
                          stem: slice[i].stem,
                          branch: slice[i].branch,
                          aboveLabel: slice[i].label,
                          current: slice[i].year == thisYear,
                          currentLabel: thisYearLabel,
                          semanticLabel: slice[i].semanticLabel,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s8,
        children: rows,
      );
    },
  );
}

/// 기둥 하나: 위 꼬리표 자리, 위 숫자, (십성) 천간·지지 칸 (십성) (12운성), 아래 숫자. 지금이면
/// `highlight.current`.
///
/// 라벨 줄은 [rows] 높이로 두어 같은 줄 기둥끼리 칸이 나란하고, 라벨이 없는 기둥도 자리를
/// 남깁니다. 칸 위 라벨은 칸 쪽(아래)에, 칸 아래 라벨은 칸 쪽(위)에 붙습니다. 스크린리더는 칸을
/// 위에서 아래로 하나씩 읽고, 지금이면 위 숫자 뒤에 꼬리표를 읽습니다.
class _Pillar extends StatelessWidget {
  const new({
    required this.width,
    required this.rows,
    required this.top,
    required this.topSemanticLabel,
    required this.stem,
    required this.branch,
    required this.current,
    required this.currentLabel,
    required this.semanticLabel,
    this.bottom,
    this.bottomSemanticLabel,
    this.aboveLabel,
    this.belowLabel,
    this.stageLabel,
    super.key,
  });

  final double width;
  final _LabelRows rows;
  final String top;
  final String topSemanticLabel;
  final OhaengCell stem;
  final OhaengCell branch;
  final String? bottom;
  final String? bottomSemanticLabel;
  final LuckLabel? aboveLabel;
  final LuckLabel? belowLabel;
  final LuckLabel? stageLabel;
  final bool current;
  final String currentLabel;
  final String semanticLabel;

  /// 라벨 줄 하나. [height]가 0이면(그 줄에 라벨이 하나도 없음) 두지 않습니다.
  List<Widget> _labelRow({
    required LuckLabel? label,
    required double height,
    required double gapBefore,
    required Alignment alignment,
  }) {
    if (height == 0) return const [];
    return [
      SizedBox(height: gapBefore),
      SizedBox(
        height: height,
        child: Align(
          alignment: alignment,
          child: label == null
              ? null
              : Semantics(
                  container: true,
                  child: LuckLabelView(label: label, width: width),
                ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final numberStyle = tokens.typography.numericTable.copyWith(
      color: colors.textSecondary,
    );
    final topStyle = current
        ? numberStyle.copyWith(
            color: colors.actionPrimary,
            fontWeight: FontWeight.w700,
          )
        : numberStyle;
    final bottomText = bottom;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            // 꼬리표 자리는 모든 기둥이 같은 높이로 둡니다(줄이 흔들리지 않게).
            ExcludeSemantics(
              child: Visibility.maintain(
                visible: current,
                child: StatusTag(currentLabel),
              ),
            ),
            const SizedBox(height: Space.s4),
            DecoratedBox(
              key: DaeunTable.highlightKey,
              decoration: BoxDecoration(
                color: current ? colors.statusBg : null,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s4),
                child: Column(
                  children: [
                    Semantics(
                      label: current
                          ? '$topSemanticLabel, $currentLabel'
                          : topSemanticLabel,
                      child: ExcludeSemantics(
                        child: Text(top, style: topStyle),
                      ),
                    ),
                    ..._labelRow(
                      label: aboveLabel,
                      height: rows.above,
                      gapBefore: Space.s4,
                      alignment: Alignment.bottomCenter,
                    ),
                    const SizedBox(height: Space.s4),
                    Semantics(
                      label: semanticLabel,
                      child: ExcludeSemantics(
                        child: Column(
                          children: [stem, const SizedBox(height: 2), branch],
                        ),
                      ),
                    ),
                    ..._labelRow(
                      label: belowLabel,
                      height: rows.below,
                      gapBefore: Space.s4,
                      alignment: Alignment.topCenter,
                    ),
                    ..._labelRow(
                      label: stageLabel,
                      height: rows.stage,
                      gapBefore: 2,
                      alignment: Alignment.topCenter,
                    ),
                    if (bottomText != null) ...[
                      const SizedBox(height: Space.s4),
                      Semantics(
                        label: bottomSemanticLabel,
                        child: ExcludeSemantics(
                          child: Text(bottomText, style: numberStyle),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
