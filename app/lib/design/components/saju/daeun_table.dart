import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 대운 기둥 하나.
@immutable
final class DaeunPillar {
  /// [age](한국식 나이)에 시작하는 대운. [semanticLabel]은 스크린리더가 읽는 글입니다.
  const new({
    required this.age,
    required this.startYear,
    required this.stem,
    required this.branch,
    required this.semanticLabel,
  });

  /// 시작 나이(한국식, core C22).
  final int age;

  /// 시작 연도.
  final int startYear;

  /// 천간 `mini` 칸.
  final OhaengCell stem;

  /// 지지 `mini` 칸.
  final OhaengCell branch;

  /// 스크린리더 글.
  final String semanticLabel;
}

/// 세운(한 해) 칸.
@immutable
final class SeunYear {
  /// [year]의 세운.
  const new({
    required this.year,
    required this.stem,
    required this.branch,
    required this.semanticLabel,
  });

  /// 연도.
  final int year;

  /// 천간 `mini` 칸.
  final OhaengCell stem;

  /// 지지 `mini` 칸.
  final OhaengCell branch;

  /// 스크린리더 글.
  final String semanticLabel;
}

/// 대운·세운 표(`daeun-table`).
///
/// 대운은 가로로 넘기는 기둥 줄(너비 52, 사이 4)이고 기둥마다 한국식 나이·천간·지지
/// `ohaeng.cell` `mini`·시작 연도입니다. 세운은 지금 대운 10년을 5열 2줄로 둡니다.
///
/// 지금 대운([currentIndex])은 `highlight.current`(바탕 `status.bg`,
/// 나이 `action.primary` 굵게)와 위에 [nowLabel] 꼬리표(`tag.status`)입니다.
/// 올해 세운([thisYear])도 같은 강조와 [thisYearLabel] 꼬리표입니다
/// (`current`·`thisYear`). 낙관 윤곽은 쓰지 않습니다.
///
/// 처음 열 때 지금 대운이 보이게 가로 위치를 맞춰 두고 움직이지 않습니다.
/// 글자 크기는 1.3배에서 멈춥니다.
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
              builder: (context, constraints) => SingleChildScrollView(
                key: DaeunTable.daeunScrollKey,
                controller: _controllerFor(constraints.maxWidth),
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (index, pillar) in widget.daeun.indexed) ...[
                      if (index > 0)
                        const SizedBox(width: DaeunTable.pillarGap),
                      _Pillar(
                        key: DaeunTable.daeunKey(index),
                        width: DaeunTable.pillarWidth,
                        top: '${pillar.age}',
                        stem: pillar.stem,
                        branch: pillar.branch,
                        bottom: '${pillar.startYear}',
                        current: index == widget.currentIndex,
                        currentLabel: widget.nowLabel,
                        semanticLabel: pillar.semanticLabel,
                      ),
                    ],
                  ],
                ),
              ),
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
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < seun.length; start += _columns) {
      final slice = seun.sublist(
        start,
        math.min(start + _columns, seun.length),
      );
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < _columns; i++) ...[
              if (i > 0) const SizedBox(width: DaeunTable.pillarGap),
              Expanded(
                child: i < slice.length
                    ? _Pillar(
                        key: DaeunTable.seunKey(slice[i].year),
                        top: '${slice[i].year}',
                        stem: slice[i].stem,
                        branch: slice[i].branch,
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
  }
}

/// 기둥 하나: 위 꼬리표 자리, 위 숫자, 천간·지지 칸, 아래 숫자. 지금이면 `highlight.current`.
class _Pillar extends StatelessWidget {
  const new({
    required this.top,
    required this.stem,
    required this.branch,
    required this.current,
    required this.currentLabel,
    required this.semanticLabel,
    this.bottom,
    this.width,
    super.key,
  });

  final String top;
  final OhaengCell stem;
  final OhaengCell branch;
  final String? bottom;
  final bool current;
  final String currentLabel;
  final String semanticLabel;
  final double? width;

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
      label: current ? '$semanticLabel, $currentLabel' : semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            // 꼬리표 자리는 모든 기둥이 같은 높이로 둡니다(줄이 흔들리지 않게).
            Visibility.maintain(
              visible: current,
              child: StatusTag(currentLabel),
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
                    Text(top, style: topStyle),
                    const SizedBox(height: Space.s4),
                    stem,
                    const SizedBox(height: 2),
                    branch,
                    if (bottomText != null) ...[
                      const SizedBox(height: Space.s4),
                      Text(bottomText, style: numberStyle),
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
