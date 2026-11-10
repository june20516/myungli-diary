import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/highlight_current.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/stem_chip.dart';
import 'package:myungli_diary/design/elements/tag_me.dart';
import 'package:myungli_diary/design/text/line_height.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 띠(속성 줄) 종류. 위에서부터 이 순서로 그립니다.
enum BandKind {
  /// 지장간.
  hiddenStems,

  /// 12운성.
  twelveStages,

  /// 신살.
  shinsal,
}

/// 지장간 하나: 오행 색 천간 칩과 십성 라벨 한 줄.
@immutable
final class BandHiddenStem {
  /// 지장간을 만듭니다. [semanticLabel]은 한자와 독음(스크린리더, 칩은 읽지 않음)입니다.
  const new({
    required this.element,
    required this.hanja,
    required this.semanticLabel,
    this.tenGod,
  });

  /// 천간의 오행(칩 색).
  final FiveElement element;

  /// 천간 한자 한 글자.
  final String hanja;

  /// 스크린리더가 읽는 한자와 독음.
  final String semanticLabel;

  /// 십성 라벨(`term-token` `label`). 없으면 칩만 그립니다.
  final LuckLabel? tenGod;
}

/// 네 열 가운데 한 열(기둥 하나)의 띠 값.
@immutable
final class BandColumn {
  /// 열을 만듭니다. [empty]면 모든 띠가 빈 칸입니다(시간 모름의 시주 열).
  const new({
    required this.header,
    this.isDay = false,
    this.empty = false,
    this.hiddenStems = const [],
    this.twelveStage,
    this.shinsal = const [],
  });

  /// 열 머리(시주, 일주, 월주, 연주).
  final String header;

  /// 일주 열인지(옅은 바탕, 열 머리 `action.primary` 700과 `tag.me`).
  final bool isDay;

  /// 값이 없는 열인지(시간 모름의 시주). 열 머리는 그대로입니다.
  final bool empty;

  /// 지장간(계약 배열 순서).
  final List<BandHiddenStem> hiddenStems;

  /// 12운성 라벨. 없으면 빈 칸입니다.
  final LuckLabel? twelveStage;

  /// 신살들. 없으면 빈 칸입니다.
  final List<LuckLabel> shinsal;
}

/// 네 열 속성 띠 표(`band-table`, V89): 시주, 일주, 월주, 연주 네 열을 끝까지 유지하고 열
/// 구분선이 모든 띠를 관통하며, 일주 열은 옅은 바탕, 네 열에 걸친 띠 머리줄이 띠를 가릅니다.
///
/// 흰 카드(`bg.sheet`, `radius.lg`, 좌우 `space.12`, 위아래 `space.4`) 안에서 네 열은 같은
/// 폭입니다. 띠 이름은 가운데 `term-token` `label`이고 누르면 [onBandTap](설명 시트)입니다.
/// 값이 없는 칸은 12 × 1 가로선이고 스크린리더는 [emptyLabel]을 읽습니다. 선은 칸 위
/// `space.8` 아래 그 띠 내용 한 줄 높이의 상자([emptyBoxHeightOf]) 세로 가운데에 놓여 이웃
/// 칸 첫 줄 글자와 같은 높이에 옵니다(`parts.empty.box`, V101). 불러오는 중
/// ([loading])에는 열 머리, 띠 머리줄, 열 구분선, 일주 열 바탕은 그대로 두고 칸마다 칩 모양
/// 뼈를 그립니다. 글자 배율은 1.3배에서 멈춥니다(`textScaleMax`).
class BandTable extends StatelessWidget {
  /// 표를 만듭니다. [columns]는 시, 일, 월, 연 순서의 넷입니다.
  const new({
    required this.columns,
    required this.bandLabels,
    required this.onBandTap,
    required this.meLabel,
    required this.emptyLabel,
    required this.tableLabel,
    this.loading = false,
    this.animated = true,
    super.key,
  }) : assert(columns.length == 4, '열은 시, 일, 월, 연 넷입니다');

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('band-table', {}, {
    'time-unknown',
    'loading',
  });

  /// 일주 열 바탕을 찾는 테스트용 키.
  static const Key dayColumnKey = ValueKey('band-table-day-column');

  /// 열 구분선(바탕 층)을 찾는 테스트용 키.
  static const Key dividerKey = ValueKey('band-table-column-divider');

  /// 띠 머리줄을 찾는 테스트용 키.
  static const Key bandHeaderKey = ValueKey('band-table-band-header');

  /// 값이 없는 칸의 가로선을 찾는 테스트용 키.
  static const Key emptyLineKey = ValueKey('band-table-empty-line');

  /// 값이 없는 칸의 가로선 폭. 계약 `saju.json` `band-table.parts.empty.width`.
  static const double emptyLineWidth = 12;

  /// 값이 없는 칸의 가로선 두께. 계약 `band-table.parts.empty.height`.
  static const double emptyLineHeight = 1;

  /// 값이 없는 칸의 선 상자를 찾는 테스트용 키.
  static const Key emptyBoxKey = ValueKey('band-table-empty-box');

  /// 칸 위 여백이자 빈 칸 선 상자의 시작 자리. 계약 `parts.cell.paddingTop`,
  /// `parts.empty.box.offsetTop`(둘 다 `space.8`).
  static const double cellPaddingTop = Space.s8;

  /// 칸 아래 여백. 계약 `parts.cell.paddingBottom`.
  static const double cellPaddingBottom = Space.s12;

  /// 지장간 띠 빈 칸 선 상자 높이(`stem.chip` 크기).
  ///
  /// 계약 `empty.box.heightByBand.hiddenStems`.
  static const double emptyBoxStemHeight = StemChip.side;

  /// [kind] 띠 빈 칸 선 상자 높이(`parts.empty.box.heightByBand`): 지장간은 `stem.chip` 22,
  /// 12운성과 신살은 `term-token` `label` 칩 한 줄(위아래 여백 없는 `type.caption.md` 한 줄)
  /// 높이입니다. 칩 글자와 같은 배율([scaler])을 씁니다.
  static double emptyBoxHeightOf(
    BandKind kind,
    TextStyle labelStyle,
    TextScaler scaler,
  ) => switch (kind) {
    BandKind.hiddenStems => emptyBoxStemHeight,
    BandKind.twelveStages ||
    BandKind.shinsal => lineHeightOf(labelStyle, scaler),
  };

  /// 글자 크기를 멈추는 배율.
  static const double textScaleMax = 1.3;

  /// 칸 좌우 안쪽 여백(칸 안 라벨 폭 계산).
  static const double cellPaddingX = 2;

  /// 시, 일, 월, 연 순서의 네 열.
  final List<BandColumn> columns;

  /// 띠 이름(띠 머리줄의 용어 칩 글자).
  final Map<BandKind, String> bandLabels;

  /// 띠 머리줄의 용어 칩을 눌렀을 때(설명 시트 열기).
  final void Function(BandKind kind) onBandTap;

  /// 일주 열 머리 뒤 `tag.me` 꼬리표 글자.
  final String meLabel;

  /// 값이 없는 칸의 스크린리더 글자.
  final String emptyLabel;

  /// 표 이름(스크린리더).
  final String tableLabel;

  /// 불러오는 중인지.
  final bool loading;

  /// false면 뼈가 움직이지 않습니다(golden 등).
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: textScaleMax,
      child: Semantics(
        container: true,
        role: SemanticsRole.table,
        label: tableLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.bgSheet,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s12,
              vertical: Space.s4,
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _ColumnGrid(columns: columns)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerRow(context),
                    for (final (index, kind) in BandKind.values.indexed) ...[
                      _bandHeader(context, kind),
                      _bandRow(context, kind, index),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 네 칸을 같은 폭으로 나란히 둔 줄.
  Widget _row(List<Widget> cells) => Semantics(
    container: true,
    role: SemanticsRole.row,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final cell in cells) Expanded(child: cell)],
    ),
  );

  Widget _headerRow(BuildContext context) {
    final tokens = context.tokens;
    return _row([
      for (final column in columns)
        Semantics(
          container: true,
          role: SemanticsRole.columnHeader,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s8),
            child: Center(
              child: column.isDay
                  // 한 줄에 못 들어가면 꼬리표가 아래 줄로 내려갑니다(글자는 줄이지 않음).
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.s4,
                      runSpacing: Space.s2,
                      children: [
                        Text(
                          column.header,
                          softWrap: false,
                          style: tokens.typography.captionMd.copyWith(
                            color: tokens.colors.actionPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        ExcludeSemantics(child: TagMe(meLabel)),
                      ],
                    )
                  : Text(
                      column.header,
                      textAlign: TextAlign.center,
                      style: tokens.typography.captionMd.copyWith(
                        color: tokens.colors.textSecondary,
                      ),
                    ),
            ),
          ),
        ),
    ]);
  }

  /// 네 열에 걸친 띠 머리줄: 흰 바탕이 열 구분선과 일주 바탕을 덮고 위아래 0.5px `line`.
  Widget _bandHeader(BuildContext context, BandKind kind) {
    final colors = context.tokens.colors;
    const hairline = BorderSide(width: BorderTokens.hairline);
    final side = hairline.copyWith(color: colors.line);
    return Padding(
      padding: const EdgeInsets.only(top: Space.s8),
      child: DecoratedBox(
        key: bandHeaderKey,
        decoration: BoxDecoration(
          color: colors.bgSheet,
          border: Border(top: side, bottom: side),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s8),
          child: Semantics(
            container: true,
            role: SemanticsRole.row,
            child: Semantics(
              container: true,
              role: SemanticsRole.cell,
              child: Center(
                child: TermToken(
                  label: bandLabels[kind] ?? '',
                  variant: TermTokenVariant.label,
                  onTap: () => onBandTap(kind),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bandRow(BuildContext context, BandKind kind, int bandIndex) => _row([
    for (final (index, column) in columns.indexed)
      Padding(
        padding: const EdgeInsets.only(
          top: cellPaddingTop,
          bottom: cellPaddingBottom,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: _Cell(
            table: this,
            kind: kind,
            column: column,
            boneIndex: bandIndex * 4 + index,
          ),
        ),
      ),
  ]);
}

/// 바탕 층: 일주 열 바탕과 열 구분선(0.5px `line`)이 열 머리부터 끝까지 이어집니다.
class _ColumnGrid extends StatelessWidget {
  const new({required this.columns});

  final List<BandColumn> columns;

  @override
  Widget build(BuildContext context) {
    final line = context.tokens.colors.line;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (index, column) in columns.indexed)
            Expanded(
              child: DecoratedBox(
                key: column.isDay ? BandTable.dayColumnKey : null,
                decoration: BoxDecoration(
                  border: index == 0
                      ? null
                      : Border(
                          left: BorderSide(
                            color: line,
                            width: BorderTokens.hairline,
                          ),
                        ),
                ),
                child: column.isDay
                    ? const HighlightCurrent(child: SizedBox.expand())
                    : const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

/// 띠 칸 하나(열 × 띠).
class _Cell extends StatelessWidget {
  const new({
    required this.table,
    required this.kind,
    required this.column,
    required this.boneIndex,
  });

  final BandTable table;
  final BandKind kind;
  final BandColumn column;
  final int boneIndex;

  bool get _empty => switch (kind) {
    _ when column.empty => true,
    BandKind.hiddenStems => column.hiddenStems.isEmpty,
    BandKind.twelveStages => column.twelveStage == null,
    BandKind.shinsal => column.shinsal.isEmpty,
  };

  @override
  Widget build(BuildContext context) {
    final bandName = table.bandLabels[kind] ?? '';
    final prefix = [bandName, column.header];
    if (table.loading) {
      return ExcludeSemantics(child: _bones());
    }
    if (_empty) {
      return Semantics(
        container: true,
        role: SemanticsRole.cell,
        label: [...prefix, table.emptyLabel].join(', '),
        child: ExcludeSemantics(
          // 칸 위 space.8(칸 여백) 아래 그 띠 한 줄 높이 상자의 세로 가운데에 선을 둡니다.
          child: SizedBox(
            key: BandTable.emptyBoxKey,
            height: BandTable.emptyBoxHeightOf(
              kind,
              context.tokens.typography.captionMd,
              MediaQuery.textScalerOf(context),
            ),
            child: Center(
              widthFactor: 1,
              child: SizedBox(
                key: BandTable.emptyLineKey,
                width: BandTable.emptyLineWidth,
                height: BandTable.emptyLineHeight,
                child: ColoredBox(color: context.tokens.colors.textSecondary),
              ),
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - BandTable.cellPaddingX * 2;
        return Semantics(
          container: true,
          role: SemanticsRole.cell,
          label: prefix.join(', '),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BandTable.cellPaddingX,
            ),
            child: switch (kind) {
              BandKind.hiddenStems => _hiddenStems(width),
              BandKind.twelveStages => LuckLabelView(
                label: column.twelveStage!,
                width: width,
              ),
              BandKind.shinsal => Column(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.s4,
                children: [
                  for (final label in column.shinsal)
                    LuckLabelView(label: label, width: width),
                ],
              ),
            },
          ),
        );
      },
    );
  }

  /// 지장간 여럿은 세로로 쌓습니다. 하나는 칩 + `space.4` + 십성 한 줄입니다.
  Widget _hiddenStems(double width) {
    const gap = Space.s4;
    final labelWidth = width - StemChip.side - gap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s4,
      children: [
        for (final stem in column.hiddenStems)
          Semantics(
            container: true,
            label: stem.semanticLabel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StemChip(element: stem.element, hanja: stem.hanja),
                if (stem.tenGod case final tenGod?) ...[
                  const SizedBox(width: gap),
                  Flexible(
                    child: LuckLabelView(label: tenGod, width: labelWidth),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// 칸 뼈: 지장간은 칩 + 십성 모양, 나머지는 라벨 모양 하나.
  Widget _bones() {
    const labelBone = 36.0;
    Widget label() => SkeletonBone(
      width: labelBone,
      height: SkeletonBone.lineHeight + Space.s4,
      borderRadius: Radii.xs,
      index: boneIndex,
      animated: table.animated,
    );
    if (kind != BandKind.hiddenStems) return label();
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s4,
      children: [
        SkeletonBone(
          width: StemChip.side,
          height: StemChip.side,
          borderRadius: Radii.sm,
          index: boneIndex,
          animated: table.animated,
        ),
        label(),
      ],
    );
  }
}
