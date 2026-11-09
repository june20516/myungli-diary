import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/frame/scroll_hint.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/tag_slot.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 대운 기둥 하나.
@immutable
final class DaeunPillar {
  /// [age](한국식 나이)에 시작하는 대운. 낭독 글은 칸마다 따로 받습니다.
  const new({
    required this.age,
    required this.startYear,
    required this.pillar,
    required this.ageSemanticLabel,
    required this.semanticLabel,
    required this.yearSemanticLabel,
    this.stemLabel,
    this.branchLabel,
    this.stageLabel,
  });

  /// 시작 나이(한국식, core C22).
  final int age;

  /// 시작 연도(계약 `DaeunPeriod.startYear`).
  final int startYear;

  /// 간지.
  final LuckGanji pillar;

  /// 나이 낭독 글.
  final String ageSemanticLabel;

  /// 간지 낭독 글(천간, 지지 한자와 독음).
  final String semanticLabel;

  /// 시작 연도 낭독 글.
  final String yearSemanticLabel;

  /// 천간 위 십성(`term-token` `label`). 없으면 자리만 남깁니다.
  final LuckLabel? stemLabel;

  /// 지지 아래 십성(정기). 없으면 자리만 남깁니다.
  final LuckLabel? branchLabel;

  /// 지지 십성 아래 12운성. 없으면 자리만 남깁니다.
  final LuckLabel? stageLabel;
}

/// 세운(한 해) 기둥.
@immutable
final class SeunYear {
  /// [year]의 세운.
  const new({
    required this.year,
    required this.pillar,
    required this.yearSemanticLabel,
    required this.semanticLabel,
    this.label,
  });

  /// 연도.
  final int year;

  /// 간지.
  final LuckGanji pillar;

  /// 연도 낭독 글.
  final String yearSemanticLabel;

  /// 간지 낭독 글(천간, 지지 한자와 독음).
  final String semanticLabel;

  /// 천간 위 그 해의 천간 십성(`term-token` `label`). 없으면 자리만 남깁니다.
  final LuckLabel? label;
}

/// 대운, 세운 줄(`daeun-table`, V90): 섹션 머리(`section-header` `plain`, 한 줄 설명 늘 보임)와
/// 흰 카드 한 장씩에 `luck-pillar` `column` 기둥을 가로로 넘기는 줄 둘, 줄마다 `scroll-hint`.
///
/// 카드는 `bg.sheet`, `radius.lg`, 위아래 `space.12`이고 줄은 좌우 `space.12`, 기둥 사이
/// `space.4`입니다. 대운 기둥은 나이, 천간 십성, 간지, 지지 십성, 12운성, 시작 연도이고 세운
/// 기둥은 연도, 천간 십성, 간지뿐입니다(계약에 지지 십성, 12운성이 없음). 같은 줄의 기둥은 라벨
/// 줄마다 가장 높은 라벨에 높이를 맞춰 간지 칸이 가로로 나란합니다.
///
/// 지금 대운([currentIndex])과 올해 세운([thisYear])은 `luck-pillar` `current`이고, 처음 열 때
/// 그 칸이 줄 가운데 오도록(넘길 수 있는 범위 안) 움직임 없이 넘겨 둡니다. 두 줄은 따로 넘깁니다.
///
/// 스크린리더는 줄마다 목록(이름은 섹션 제목)이고 항목은 기둥 그룹입니다. 그룹 라벨은 나이 또는
/// 연도, 누를 수 없는 라벨, 간지, 시작 연도이고 누를 수 있는 칩은 따로 초점을 받습니다. 기둥
/// 줄의 글자 크기는 1.3배에서 멈추고, 섹션 머리는 기기 글자 배율을 그대로 따릅니다.
class DaeunTable extends StatefulWidget {
  /// 두 줄을 만듭니다.
  const new({
    required this.daeun,
    required this.seun,
    required this.currentIndex,
    required this.thisYear,
    required this.nowLabel,
    required this.thisYearLabel,
    required this.daeunTitle,
    required this.daeunDescription,
    required this.seunTitle,
    required this.seunDescription,
    super.key,
  }) : loading = false,
       animated = true;

  /// 불러오는 중(`states.loading`): 섹션 머리는 그대로 두고 카드마다 보이는 기둥 수만큼
  /// `luck-pillar` 뼈를 둡니다.
  const new loading({
    required this.daeunTitle,
    required this.daeunDescription,
    required this.seunTitle,
    required this.seunDescription,
    this.animated = true,
    super.key,
  }) : loading = true,
       daeun = const [],
       seun = const [],
       currentIndex = null,
       thisYear = null,
       nowLabel = '',
       thisYearLabel = '';

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('daeun-table', {}, {
    'loading',
  });

  /// 기둥 사이(`row.gap` `space.4`).
  static const double pillarGap = Space.s4;

  /// 줄 좌우 안쪽 여백(`row.paddingX` `space.12`).
  static const double rowPaddingX = Space.s12;

  /// 카드 위아래 안쪽 여백(`row.container.paddingY` `space.12`).
  static const double cardPaddingY = Space.s12;

  /// 기둥 줄의 글자 크기를 멈추는 배율(섹션 머리는 멈추지 않음).
  static const double textScaleMax = 1.3;

  /// 대운 줄(가로 스크롤)을 찾는 테스트용 키.
  static const Key daeunScrollKey = ValueKey('daeun-table-daeun');

  /// 세운 줄(가로 스크롤)을 찾는 테스트용 키.
  static const Key seunScrollKey = ValueKey('daeun-table-seun');

  /// [index] 대운 기둥을 찾는 테스트용 키.
  static Key daeunKey(int index) => ValueKey('daeun-table-daeun-$index');

  /// [year] 세운 기둥을 찾는 테스트용 키.
  static Key seunKey(int year) => ValueKey('daeun-table-seun-$year');

  /// [index]번째 기둥 뼈를 찾는 테스트용 키.
  static Key skeletonPillarKey(int index) =>
      ValueKey('daeun-table-skeleton-pillar-$index');

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

  /// 대운 섹션 제목(`saju-chart.daeun.title`).
  final String daeunTitle;

  /// 대운 섹션 한 줄 설명(`saju-chart.daeun.desc`).
  final String daeunDescription;

  /// 세운 섹션 제목(`saju-chart.seun.title`).
  final String seunTitle;

  /// 세운 섹션 한 줄 설명(`saju-chart.seun.desc`).
  final String seunDescription;

  /// 불러오는 중인지.
  final bool loading;

  /// false면 뼈가 움직이지 않습니다(golden 등).
  final bool animated;

  @override
  State<DaeunTable> createState() => _DaeunTableState();
}

class _DaeunTableState extends State<DaeunTable> {
  ScrollController? _daeunScroll;
  ScrollController? _seunScroll;

  @override
  void dispose() {
    _daeunScroll?.dispose();
    _seunScroll?.dispose();
    super.dispose();
  }

  /// [current] 기둥이 줄 가운데 오는 처음 위치(넘길 수 있는 범위 안). 지금 칸이 없으면 처음.
  static double _initialOffset({
    required int count,
    required int? current,
    required double viewport,
  }) {
    if (current == null || count == 0) return 0;
    const step = LuckPillar.columnWidth + DaeunTable.pillarGap;
    final content =
        DaeunTable.rowPaddingX * 2 + count * step - DaeunTable.pillarGap;
    final center =
        DaeunTable.rowPaddingX + current * step + LuckPillar.columnWidth / 2;
    return (center - viewport / 2)
        .clamp(0, math.max(0, content - viewport))
        .toDouble();
  }

  ScrollController _daeunController(double viewport) =>
      _daeunScroll ??= ScrollController(
        initialScrollOffset: _initialOffset(
          count: widget.daeun.length,
          current: widget.currentIndex,
          viewport: viewport,
        ),
      );

  ScrollController _seunController(double viewport) {
    final index = widget.seun.indexWhere((y) => y.year == widget.thisYear);
    return _seunScroll ??= ScrollController(
      initialScrollOffset: _initialOffset(
        count: widget.seun.length,
        current: index < 0 ? null : index,
        viewport: viewport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    // 섹션 머리는 원국 탭 섹션 머리처럼 기기 글자 배율을 그대로 따르고, 기둥 줄만 1.3배에서
    // 멈춥니다(a11y.textScaleMax는 기둥 줄 몫, controller 결정 B).
    Widget card(Widget child) => MediaQuery.withClampedTextScaling(
      maxScaleFactor: DaeunTable.textScaleMax,
      child: _Card(child: child),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: widget.daeunTitle,
          description: widget.daeunDescription,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        card(
          widget.loading
              ? _SkeletonRow(animated: widget.animated)
              : LayoutBuilder(
                  builder: (context, constraints) => _row(
                    context,
                    scrollKey: DaeunTable.daeunScrollKey,
                    controller: _daeunController(constraints.maxWidth),
                    label: widget.daeunTitle,
                    pillars: _daeunPillars(context),
                  ),
                ),
        ),
        const SizedBox(height: SectionHeader.sectionGap),
        SectionHeader(
          title: widget.seunTitle,
          description: widget.seunDescription,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        card(
          widget.loading
              ? _SkeletonRow(animated: widget.animated)
              : LayoutBuilder(
                  builder: (context, constraints) => _row(
                    context,
                    scrollKey: DaeunTable.seunScrollKey,
                    controller: _seunController(constraints.maxWidth),
                    label: widget.seunTitle,
                    pillars: _seunPillars(context),
                  ),
                ),
        ),
      ],
    );
  }

  /// 가로로 넘기는 기둥 줄 하나와 그 `scroll-hint`. 스크린리더는 [label] 목록으로 읽습니다.
  Widget _row(
    BuildContext context, {
    required Key scrollKey,
    required ScrollController controller,
    required String label,
    required List<Widget> pillars,
  }) => ScrollHint(
    controller: controller,
    child: SingleChildScrollView(
      key: scrollKey,
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: DaeunTable.rowPaddingX),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.list,
        label: label,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DaeunTable.pillarGap,
          children: [
            for (final pillar in pillars)
              Semantics(
                container: true,
                role: SemanticsRole.listItem,
                child: pillar,
              ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _daeunPillars(BuildContext context) {
    final daeun = widget.daeun;
    const width = LuckPillar.columnWidth - LuckPillar.columnPadding * 2;
    double rowOf(LuckLabel? Function(DaeunPillar) pick) =>
        _rowHeight(context, daeun.map(pick), width);
    final rows = LuckPillarRowHeights(
      tenGod: rowOf((p) => p.stemLabel),
      branchTenGod: rowOf((p) => p.branchLabel),
      twelveStage: rowOf((p) => p.stageLabel),
    );
    return [
      for (final (index, item) in daeun.indexed)
        LuckPillar.column(
          key: DaeunTable.daeunKey(index),
          pillar: item.pillar,
          top: '${item.age}',
          tenGod: item.stemLabel,
          branchTenGod: item.branchLabel,
          twelveStage: item.stageLabel,
          startYear: '${item.startYear}',
          rowHeights: rows,
          current: index == widget.currentIndex,
          // 꼬리표 자리는 모든 기둥에 두어 줄 높이가 흔들리지 않게 합니다.
          currentTag: widget.nowLabel,
          tagEdge: TagEdge.of(index, daeun.length),
          semanticLabel: _groupLabel(context, [
            item.ageSemanticLabel,
            _plain(item.stemLabel),
            item.semanticLabel,
            _plain(item.branchLabel),
            _plain(item.stageLabel),
            item.yearSemanticLabel,
          ]),
        ),
    ];
  }

  List<Widget> _seunPillars(BuildContext context) {
    final seun = widget.seun;
    const width = LuckPillar.columnWidth - LuckPillar.columnPadding * 2;
    final rows = LuckPillarRowHeights(
      tenGod: _rowHeight(context, seun.map((y) => y.label), width),
    );
    return [
      for (final (index, item) in seun.indexed)
        LuckPillar.column(
          key: DaeunTable.seunKey(item.year),
          pillar: item.pillar,
          top: '${item.year}',
          tenGod: item.label,
          rowHeights: rows,
          current: item.year == widget.thisYear,
          currentTag: widget.thisYearLabel,
          tagEdge: TagEdge.of(index, seun.length),
          semanticLabel: _groupLabel(context, [
            item.yearSemanticLabel,
            _plain(item.label),
            item.semanticLabel,
          ]),
        ),
    ];
  }

  /// 누를 수 없는 라벨의 글자(그룹 라벨이 읽음). 누를 수 있으면 칩이 따로 읽으므로 null입니다.
  static String? _plain(LuckLabel? label) =>
      label == null || label.onTap != null ? null : label.text;

  static String _groupLabel(BuildContext context, List<String?> parts) => parts
      .nonNulls
      .where((part) => part.isNotEmpty)
      .join(AppLocalizations.of(context).a11yListSeparator);
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

/// 줄을 담는 흰 카드(`row.container`).
class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.tokens.colors.bgSheet,
      borderRadius: BorderRadius.circular(Radii.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: DaeunTable.cardPaddingY),
      child: child,
    ),
  );
}

/// 불러오는 중 줄: 보이는 폭에 들어가는 수만큼 기둥 뼈(`luck-pillar` `loading`: 십성 칩과
/// `ohaeng.cell` 칸 둘).
class _SkeletonRow extends StatelessWidget {
  const new({required this.animated});

  final bool animated;

  // 십성 칩 뼈 너비(luck-pillar states.loading skeleton tenGods width 36px).
  static const double _chipWidth = 36;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const step = LuckPillar.columnWidth + DaeunTable.pillarGap;
      final inner = constraints.maxWidth - DaeunTable.rowPaddingX * 2;
      final count = math.max(
        1,
        ((inner + DaeunTable.pillarGap) / step).floor(),
      );
      final chipHeight =
          context.tokens.typography.captionMd.fontSize! *
          context.tokens.typography.captionMd.height!;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DaeunTable.rowPaddingX),
        child: Row(
          spacing: DaeunTable.pillarGap,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                key: DaeunTable.skeletonPillarKey(i),
                width: LuckPillar.columnWidth,
                child: Column(
                  spacing: Space.s4,
                  children: [
                    SkeletonBone(
                      width: _chipWidth,
                      height: chipHeight,
                      borderRadius: Radii.xs,
                      index: i * 3,
                      animated: animated,
                    ),
                    for (var cell = 0; cell < 2; cell++)
                      SkeletonBone(
                        width: OhaengCell.smallSide,
                        height: OhaengCell.smallSide,
                        borderRadius: Radii.sm,
                        index: i * 3 + cell + 1,
                        animated: animated,
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
