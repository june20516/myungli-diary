import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 내 네 자리(기둥). 순서는 시, 일, 월, 연입니다.
enum PillarPosition {
  /// 시주.
  hour,

  /// 일주.
  day,

  /// 월주.
  month,

  /// 연주.
  year,
}

/// 12운성 띠(`stage-strip`, V91): 열두 단계를 한 줄 막대로 늘어놓고 내 네 자리(시, 일, 월,
/// 연)를 표시합니다.
///
/// 12칸은 높이 6, 사이 `space.2`, `radius.full`이고 내 자리 칸만 `action.primary`, 나머지는
/// `line`입니다. 내 자리 칸 위 가운데에 원 18 안 기둥 한 글자가 있고(같은 단계에 자리가 여럿이면
/// 시, 일, 월, 연 순으로 `space.2` 간격 나란히, 칸 폭을 넘으면 이웃 칸 위로 넘치되 트랙 양 끝
/// 밖으로는 나가지 않음), 아래에 단계 이름이 있습니다. 칸 폭에 이름이 들어가지 않으면 내 자리
/// 칸 이름만 보이고 나머지는 숨깁니다(줄이거나 자르지 않음). 강하다 약하다 같은 평가는 없습니다.
/// 스크린리더는 그림 하나로 내 자리가 있는 단계만 막대 순서로 읽습니다.
class StageStrip extends StatelessWidget {
  /// 띠를 만듭니다. [positions]는 자리별 12운성이고 시간 모름이면 시주를 뺍니다.
  /// [stageNames]는 열두 단계의 이름(사전)입니다.
  const new({required this.positions, required this.stageNames, super.key});

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('stage-strip', {}, {
    'time-unknown',
    'loading',
  });

  /// 열두 단계 순서(장생에서 양까지). 계약 `saju.json` `stage-strip.parts.stages.order`.
  static const List<TwelveStage> order = [
    TwelveStage.jangsaeng,
    TwelveStage.mokyok,
    TwelveStage.gwandae,
    TwelveStage.geonrok,
    TwelveStage.jewang,
    TwelveStage.soe,
    TwelveStage.byeong,
    TwelveStage.sa,
    TwelveStage.myo,
    TwelveStage.jeol,
    TwelveStage.tae,
    TwelveStage.yang,
  ];

  /// 칸을 찾는 테스트용 키 접두(`stage-strip-cell-<단계 값>`).
  static Key cellKey(TwelveStage stage) =>
      ValueKey('stage-strip-cell-${stage.value}');

  /// 자리 표시 원을 찾는 테스트용 키 접두(`stage-strip-marker-<자리>`).
  static Key markerKey(PillarPosition position) =>
      ValueKey('stage-strip-marker-${position.name}');

  /// 칸 높이. 계약 `stage-strip.parts.track.cellHeight`.
  static const double cellHeight = 6;

  /// 자리 표시 원 지름. 계약 `stage-strip.parts.marker.size`.
  static const double markerSize = 18;

  /// 글자 크기를 멈추는 배율.
  static const double textScaleMax = 1.3;

  /// 자리별 12운성.
  final Map<PillarPosition, TwelveStage> positions;

  /// 단계 이름.
  final Map<TwelveStage, String> stageNames;

  /// 불러오는 중(`states.loading`): 트랙 전체 폭, 높이 6의 뼈 하나.
  static Widget skeleton({int index = 0, bool animated = true}) => SkeletonBone(
    height: cellHeight,
    borderRadius: Radii.full,
    index: index,
    animated: animated,
  );

  String _pillarName(AppLocalizations l10n, PillarPosition position) =>
      switch (position) {
        PillarPosition.hour => l10n.sajuPillarHour,
        PillarPosition.day => l10n.sajuPillarDay,
        PillarPosition.month => l10n.sajuPillarMonth,
        PillarPosition.year => l10n.sajuPillarYear,
      };

  String _markerLabel(AppLocalizations l10n, PillarPosition position) =>
      switch (position) {
        PillarPosition.hour => l10n.sajuStageMarkerHour,
        PillarPosition.day => l10n.sajuStageMarkerDay,
        PillarPosition.month => l10n.sajuStageMarkerMonth,
        PillarPosition.year => l10n.sajuStageMarkerYear,
      };

  /// 단계 [stage]에 있는 내 자리들(시, 일, 월, 연 순).
  List<PillarPosition> _mineAt(TwelveStage stage) => [
    for (final position in PillarPosition.values)
      if (positions[position] == stage) position,
  ];

  /// 스크린리더 글자: "장생, 월주 / 목욕, 연주 / ..." 막대 순서, 내 자리가 있는 단계만.
  String semanticLabel(AppLocalizations l10n) {
    final separator = l10n.a11yListSeparator;
    return [
      for (final stage in order)
        if (_mineAt(stage) case final mine when mine.isNotEmpty)
          [
            stageNames[stage] ?? stage.value,
            for (final position in mine) _pillarName(l10n, position),
          ].join(separator),
    ].join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: textScaleMax,
      child: Semantics(
        container: true,
        image: true,
        label: semanticLabel(l10n),
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth =
                  (constraints.maxWidth - Space.s2 * (order.length - 1)) /
                  order.length;
              return Row(
                spacing: Space.s2,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final stage in order)
                    SizedBox(
                      width: cellWidth,
                      child: _StageCell(
                        stage: stage,
                        name: stageNames[stage] ?? '',
                        mine: _mineAt(stage),
                        markerLabel: (p) => _markerLabel(l10n, p),
                        colors: colors,
                        cellWidth: cellWidth,
                        trackWidth: constraints.maxWidth,
                        index: order.indexOf(stage),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 칸 하나: 위 자리 표시, 막대 칸, 아래 단계 이름.
class _StageCell extends StatelessWidget {
  const new({
    required this.stage,
    required this.name,
    required this.mine,
    required this.markerLabel,
    required this.colors,
    required this.cellWidth,
    required this.trackWidth,
    required this.index,
  });

  final TwelveStage stage;
  final String name;
  final List<PillarPosition> mine;
  final String Function(PillarPosition position) markerLabel;
  final ColorTokens colors;
  final double cellWidth;
  final double trackWidth;
  final int index;

  @override
  Widget build(BuildContext context) {
    final typography = context.tokens.typography;
    final isMine = mine.isNotEmpty;
    final nameStyle = typography.captionSm.copyWith(
      color: isMine ? colors.textPrimary : colors.textSecondary,
      fontWeight: isMine ? FontWeight.w600 : null,
    );
    // 이름이 칸 폭에 들어가는지 잰 뒤, 안 들어가면 내 자리 칸의 이름만 보입니다.
    final painter = TextPainter(
      text: TextSpan(text: name, style: nameStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final nameWidth = painter.width;
    final nameHeight = painter.height;
    final fits = nameWidth <= cellWidth;
    painter.dispose();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MarkerSlot(
          mine: mine,
          label: markerLabel,
          cellWidth: cellWidth,
          trackWidth: trackWidth,
          index: index,
          markerColors: colors,
          style: typography.captionSm,
        ),
        DecoratedBox(
          key: StageStrip.cellKey(stage),
          decoration: BoxDecoration(
            color: isMine ? colors.actionPrimary : colors.line,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: const SizedBox(
            height: StageStrip.cellHeight,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: Space.s4),
        if (fits || isMine)
          // 내 자리 칸 이름은 칸보다 넓어도 줄이거나 자르지 않고 가운데에서 이웃으로 넘칩니다.
          _Overflowing(
            width: nameWidth,
            height: nameHeight,
            cellWidth: cellWidth,
            trackWidth: trackWidth,
            index: index,
            child: Text(
              name,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: nameStyle,
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

/// 칸 위 자리 표시 묶음. 자리가 없는 칸도 높이는 같게 비워 둡니다.
class _MarkerSlot extends StatelessWidget {
  const new({
    required this.mine,
    required this.label,
    required this.cellWidth,
    required this.trackWidth,
    required this.index,
    required this.markerColors,
    required this.style,
  });

  final List<PillarPosition> mine;
  final String Function(PillarPosition position) label;
  final double cellWidth;
  final double trackWidth;
  final int index;
  final ColorTokens markerColors;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    const height = StageStrip.markerSize + Space.s4;
    if (mine.isEmpty) return const SizedBox(height: height);
    return SizedBox(
      height: height,
      child: _Overflowing(
        width:
            StageStrip.markerSize * mine.length + Space.s2 * (mine.length - 1),
        height: height,
        cellWidth: cellWidth,
        trackWidth: trackWidth,
        index: index,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.s4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.s2,
            children: [
              for (final position in mine)
                DecoratedBox(
                  key: StageStrip.markerKey(position),
                  decoration: BoxDecoration(
                    color: markerColors.actionPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: StageStrip.markerSize,
                    height: StageStrip.markerSize,
                    child: Center(
                      child: Text(
                        label(position),
                        textScaler: TextScaler.noScaling,
                        style: style.copyWith(
                          color: markerColors.actionOnPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 칸 가운데에 놓되 칸보다 넓으면 이웃 칸 위로 넘치는 자식. 트랙 양 끝 밖으로는 나가지 않게
/// 그 끝에 맞춥니다.
class _Overflowing extends StatelessWidget {
  const new({
    required this.width,
    required this.height,
    required this.cellWidth,
    required this.trackWidth,
    required this.index,
    required this.child,
    this.alignment = Alignment.center,
  });

  /// 자식의 폭.
  final double width;

  /// 자식의 높이(세로로는 넘치지 않음).
  final double height;
  final double cellWidth;
  final double trackWidth;
  final int index;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final center = index * (cellWidth + Space.s2) + cellWidth / 2;
    final maxLeft = trackWidth - width;
    final left = maxLeft < 0 ? 0.0 : (center - width / 2).clamp(0.0, maxLeft);
    final shift = left - (center - width / 2);
    return Transform.translate(
      offset: Offset(shift, 0),
      child: SizedBox(
        width: cellWidth,
        height: height,
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: height,
          alignment: alignment,
          child: child,
        ),
      ),
    );
  }
}
