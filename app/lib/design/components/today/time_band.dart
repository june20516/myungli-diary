import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 24시간 띠의 칸 하나(시진 하나, 2시간).
@immutable
final class TimeBandCell {
  /// [label] 글자를 [period] 색 칸에 그립니다. [picked]면 고른 시진 고리를 두릅니다.
  const new({required this.label, required this.period, this.picked = false});

  /// 칸 안 시진 이름 한 글자(ko, ja) 또는 지지 한자(en).
  final String label;

  /// 낮 칸인지 밤 칸인지(`cells.day`, `cells.night`).
  final AppTimeOfDay period;

  /// 지금 보이는 낮, 밤 칩이 고른 시진인지(`cells.pick`).
  final bool picked;
}

/// 띠 아래 눈금 하나: 시각과, 전날이나 다음 날이면 그 앞의 날 낱말.
@immutable
final class TimeBandTick {
  /// [time] 앞에 [dayWord]("어제", "내일")를 둡니다. 같은 날이면 [dayWord]가 null입니다.
  const new({required this.time, this.dayWord});

  /// 시각 글자(`HH:mm`).
  final String time;

  /// 날 낱말(`ticks.dayWords`). 없으면 시각만 그립니다.
  final String? dayWord;
}

/// 시간 칩 시트의 24시간 띠(`lucky-card` `parts.timeBand`, 결정 V117, V118 ③).
///
/// 머리(덩어리 시작의 해, 달과 낱말) → 시진 12칸(고른 시진 고리) → 눈금 순서이고, 칸 위에 지금
/// 줄과 꼬리표가 겹칩니다. 칸 순서와 값은 여는 쪽이 정합니다(07:30 전에는 밤 다섯 칸이 앞). 지금
/// 줄은 띠 시작부터 [nowFraction]만큼(지금 시각 비례) 떨어진 자리이고, 꼬리표는 띠 양 끝 가까이에서
/// 꼬리표만 안쪽으로 밀려 들어오고 선은 제자리입니다.
///
/// 스크린리더에서는 그림으로 숨깁니다. 시트 본문과 칩 라벨이 같은 정보를 말합니다(`timeBand.a11y`).
class TimeBand extends StatelessWidget {
  /// 띠를 만듭니다. [cells]는 계약 순서의 12칸이고 같은 [TimeBandCell.period]끼리 이어져
  /// 있어야 합니다(덩어리 둘).
  const new({
    required this.cells,
    required this.dayHead,
    required this.nightHead,
    required this.nowFraction,
    required this.nowLabel,
    required this.startTick,
    required this.boundaryTick,
    required this.endTick,
    this.hanjaLabels = false,
    super.key,
  }) : assert(cells.length == cellCount, '띠는 시진 $cellCount칸입니다.');

  /// 시트 본문과 띠 사이(`timeBand.when` 본문 아래 space.20).
  static const double sheetGap = Space.s20;

  /// 머리 줄 높이(`heads.height` 24). 기기 글자가 커지면 함께 커지는 최소값입니다.
  static const double headHeight = 24;

  /// 머리 아이콘 크기(`heads.iconSource` size.icon.16).
  static const AppIconSize headIconSize = AppIconSize.s16;

  /// 머리 아이콘과 낱말 사이(`heads.iconGap` space.4).
  static const double headIconGap = Space.s4;

  /// 머리 아래(`heads.gapBelow` space.16).
  static const double headGapBelow = Space.s16;

  /// 칸 수(`cells.count` 12, 시진 하나가 2시간).
  static const int cellCount = 12;

  /// 칸 사이(`cells.gap` space.2).
  static const double cellGap = Space.s2;

  /// 칸 높이(`cells.height` 30). 기기 글자가 커지면 함께 커지는 최소값입니다.
  static const double cellHeight = 30;

  /// 칸 모서리(`cells.radius` radius.xs).
  static const double cellRadius = Radii.xs;

  /// 고른 시진 고리 굵기(`cells.pick.ring.width` 2px).
  static const double ringWidth = 2;

  /// 고리와 칸 바탕 사이 `bg.sheet` 틈(`cells.pick.gap.width` 2px).
  static const double ringGap = 2;

  /// 고른 시진 칸의 고리와 틈 안쪽 채움 모서리(칸 모서리에서 고리와 틈을 뺀 값, 0 아래면 0).
  static const double pickedFillRadius = cellRadius > ringWidth + ringGap
      ? cellRadius - ringWidth - ringGap
      : 0;

  /// 고른 시진 칸 글자 굵기(`cells.pick.labelWeight` 700).
  static const FontWeight pickedLabelWeight = FontWeight.w700;

  /// 지금 줄 굵기(`now.line.width` 2px).
  static const double nowLineWidth = 2;

  /// 지금 줄이 칸 위아래로 넘치는 길이(`now.line.overhang` 6px).
  static const double nowOverhang = 6;

  /// 지금 꼬리표 좌우 여백(`now.tag.paddingX` space.4).
  static const double nowTagPaddingX = Space.s4;

  /// 칸과 눈금 사이(`ticks.gapAbove` space.8).
  static const double tickGapAbove = Space.s8;

  /// 날 낱말과 시각 사이(`ticks.dayWordGap` space.4).
  static const double dayWordGap = Space.s4;

  /// 눈금 시각의 글꼴 기능(`ticks.fontFeatures` tnum).
  static const List<FontFeature> tickFeatures = [FontFeature.tabularFigures()];

  /// 지금 줄을 찾는 테스트용 키.
  static const Key nowLineKey = ValueKey('time-band-now-line');

  /// 지금 꼬리표를 찾는 테스트용 키.
  static const Key nowTagKey = ValueKey('time-band-now-tag');

  /// [index] 칸을 찾는 테스트용 키.
  static Key cellKey(int index) => ValueKey('time-band-cell-$index');

  /// 계약 순서의 12칸.
  final List<TimeBandCell> cells;

  /// 낮 덩어리 머리 낱말(`today.lucky-time.band.day`).
  final String dayHead;

  /// 밤 덩어리 머리 낱말(`today.lucky-time.band.night`).
  final String nightHead;

  /// 띠 시작부터 지금까지가 24시간 중 얼마인지(0~1, `now.position`).
  final double nowFraction;

  /// 지금 꼬리표 글자(`today.lucky-time.band.now`, "지금 {time}").
  final String nowLabel;

  /// 띠 시작 눈금(왼쪽 맞춤).
  final TimeBandTick startTick;

  /// 낮과 밤 경계 눈금(가운데 맞춤).
  final TimeBandTick boundaryTick;

  /// 띠 끝 눈금(오른쪽 맞춤).
  final TimeBandTick endTick;

  /// 칸 글자가 지지 한자인지(en, `font.family.hanja`). ko, ja는 시진 이름이라 false입니다.
  final bool hanjaLabels;

  /// 첫 덩어리의 칸 수. 둘째 덩어리는 그 뒤 칸 전부입니다.
  int get _firstBlockLength {
    final first = cells.first.period;
    final index = cells.indexWhere((cell) => cell.period != first);
    return index < 0 ? cells.length : index;
  }

  @override
  Widget build(BuildContext context) {
    final firstLength = _firstBlockLength;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heads(context, firstLength),
          _headGap(context),
          _cellsWithNow(context),
          const SizedBox(height: tickGapAbove),
          _ticks(context, firstLength / cells.length),
        ],
      ),
    );
  }

  /// 낮과 밤 덩어리 시작의 머리. 덩어리 폭은 칸 수 비율입니다.
  Widget _heads(BuildContext context, int firstLength) {
    final secondLength = cells.length - firstLength;
    return Row(
      spacing: cellGap,
      children: [
        Expanded(flex: firstLength, child: _head(context, cells.first.period)),
        if (secondLength > 0)
          Expanded(
            flex: secondLength,
            child: _head(context, cells.last.period),
          ),
      ],
    );
  }

  Widget _head(BuildContext context, AppTimeOfDay period) {
    final tokens = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: headHeight),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: headIconGap,
          children: [
            AppIcon.timeOfDay(
              period,
              size: headIconSize,
              color: LuckyChip.timeIconColorOf(tokens.colors, period),
            ),
            Flexible(
              child: Text(
                switch (period) {
                  AppTimeOfDay.day => dayHead,
                  AppTimeOfDay.night => nightHead,
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.captionMd.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 칸 줄과 그 위에 겹친 지금 줄, 꼬리표.
  Widget _cellsWithNow(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final fraction = nowFraction.clamp(0.0, 1.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 칸 높이를 가장 높은 칸에 맞춥니다(기기 글자가 커져도 칸 줄이 고르게).
        IntrinsicHeight(
          child: Row(
            spacing: cellGap,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, cell) in cells.indexed)
                Expanded(key: cellKey(index), child: _cell(context, cell)),
            ],
          ),
        ),
        Positioned.fill(
          top: -nowOverhang,
          bottom: -nowOverhang,
          child: _FractionPlaced(
            fraction: fraction,
            child: Container(
              key: nowLineKey,
              width: nowLineWidth,
              color: colors.textPrimary,
            ),
          ),
        ),
        // 꼬리표는 줄 위 끝에 붙고, 띠 양 끝 가까이에서는 꼬리표만 안쪽으로 밀립니다.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: FractionalTranslation(
            translation: const Offset(0, -1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: nowOverhang),
              child: _FractionPlaced(
                fraction: fraction,
                child: _nowTag(tokens),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 머리와 칸 사이. 계약 `heads.gapBelow`(16)이 기본이고, 칸 위에 얹는 지금 꼬리표와 줄 넘침이
  /// 그보다 높으면 그만큼 늘려 꼬리표가 머리 줄을 덮지 않게 합니다(A134 ⑪). 꼬리표 높이는 같은
  /// 꼬리표를 보이지 않게 놓아 재므로 기기 글자 배율을 따릅니다.
  Widget _headGap(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: headGapBelow),
    child: Padding(
      padding: const EdgeInsets.only(bottom: nowOverhang),
      child: Visibility.maintain(
        visible: false,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: _nowTag(context.tokens, key: null),
        ),
      ),
    ),
  );

  Widget _nowTag(MyungliTokens tokens, {Key? key = nowTagKey}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: nowTagPaddingX),
    decoration: BoxDecoration(
      color: tokens.colors.inverseBg,
      borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
    ),
    child: Text(
      nowLabel,
      maxLines: 1,
      style: tokens.typography.captionSm.copyWith(
        color: tokens.colors.inverseFg,
        fontFeatures: tickFeatures,
      ),
    ),
  );

  Widget _cell(BuildContext context, TimeBandCell cell) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final (bg, fg) = switch (cell.period) {
      AppTimeOfDay.day => (colors.ohaengEarthBg, colors.ohaengEarthFg),
      AppTimeOfDay.night => (colors.ohaengWaterBg, colors.ohaengWaterFg),
    };
    final hanja = tokens.typography.hanjaPillar;
    var style = tokens.typography.captionSm.copyWith(
      color: fg,
      fontWeight: cell.picked ? pickedLabelWeight : null,
    );
    if (hanjaLabels) {
      style = style.copyWith(
        fontFamily: hanja.fontFamily,
        fontFamilyFallback: hanja.fontFamilyFallback,
      );
    }
    final label = Center(
      child: Text(cell.label, maxLines: 1, softWrap: false, style: style),
    );
    const radius = BorderRadius.all(Radius.circular(cellRadius));
    // 고리와 틈은 칸 크기 안쪽에 그려 이웃 칸과 겹치지 않고 칸 크기가 같습니다.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: cellHeight),
      child: cell.picked
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bgSheet,
                borderRadius: radius,
                border: Border.all(
                  color: colors.actionPrimary,
                  width: ringWidth,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(ringWidth + ringGap),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    // 고리와 틈 안쪽 모서리. radius.xs(4)에서 고리와 틈(4)을 빼면 0이라 지금은 각진
                    // 채움이고, 토큰이 바뀌면 고리와 같은 중심의 둥근 모서리가 됩니다.
                    borderRadius: BorderRadius.circular(pickedFillRadius),
                  ),
                  child: label,
                ),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(color: bg, borderRadius: radius),
              child: label,
            ),
    );
  }

  /// 시작(왼쪽), 경계(가운데, [boundaryFraction] 자리), 끝(오른쪽) 눈금.
  Widget _ticks(BuildContext context, double boundaryFraction) {
    final tokens = context.tokens;
    final style = tokens.typography.captionSm.copyWith(
      color: tokens.colors.textSecondary,
      fontFeatures: tickFeatures,
    );
    Widget tick(TimeBandTick tick) {
      final dayWord = tick.dayWord;
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: dayWordGap,
        children: [
          if (dayWord != null) Text(dayWord, maxLines: 1, style: style),
          Text(tick.time, maxLines: 1, style: style),
        ],
      );
    }

    return Stack(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: tick(startTick),
        ),
        Align(alignment: AlignmentDirectional.centerEnd, child: tick(endTick)),
        _FractionPlaced(fraction: boundaryFraction, child: tick(boundaryTick)),
      ],
    );
  }
}

/// [child]의 가운데를 폭의 [fraction] 자리에 두되, 상자 밖으로 나가면 안쪽으로 밀어 넣습니다.
///
/// 폭은 부모 폭 전부, 높이는 [child] 높이(부모가 높이를 정하면 그 높이)입니다. 시작은 쓰기
/// 방향과 상관없이 왼쪽입니다(띠는 시간 순서라 늘 왼쪽에서 오른쪽).
class _FractionPlaced extends SingleChildRenderObjectWidget {
  const new({required this.fraction, required super.child});

  final double fraction;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFractionPlaced(fraction);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderFractionPlaced).fraction = fraction;
}

class _RenderFractionPlaced extends RenderShiftedBox {
  new(this._fraction) : super(null);

  double _fraction;

  double get fraction => _fraction;

  set fraction(double value) {
    if (_fraction == value) return;
    _fraction = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    final width = constraints.maxWidth;
    child.layout(
      BoxConstraints(
        maxWidth: width,
        minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        maxHeight: constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(width, child.size.height));
    final centered = width * _fraction - child.size.width / 2;
    final left = math.max(0, math.min(centered, width - child.size.width));
    (child.parentData! as BoxParentData).offset = Offset(left.toDouble(), 0);
  }
}
