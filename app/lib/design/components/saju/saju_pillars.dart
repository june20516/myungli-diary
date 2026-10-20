import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/tag_me.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 원국표의 기둥 한 열.
@immutable
final class SajuPillarColumn {
  /// 열을 만듭니다. [stem]·[branch]가 null이면 그 칸은 점선 빈 칸입니다(시간 모름의 시주).
  const new({
    required this.header,
    required this.semanticLabel,
    this.stem,
    this.branch,
    this.stemLabel,
    this.branchLabel,
  });

  /// 열 머리 글자(시주·일주·월주·연주).
  final String header;

  /// 스크린리더가 이 열을 읽는 글(기둥 이름, 천간·지지 한자와 독음, 오행, 십성).
  final String semanticLabel;

  /// 천간 칸.
  final OhaengCell? stem;

  /// 지지 칸.
  final OhaengCell? branch;

  /// 천간 위 라벨(십성 `term-token` `label`, 일주는 "일간").
  final Widget? stemLabel;

  /// 지지 아래 라벨(정기 기준 십성 `term-token` `label`).
  final Widget? branchLabel;
}

/// 원국표(`saju-pillars`): 시·일·월·연 네 기둥(다른 만세력과 같은 배치).
///
/// 열 사이 6, 머리 `type.caption.md` `text.secondary` 가운데. 천간 위·지지 아래에 십성 라벨,
/// 천간·지지는 `ohaeng.cell` `pillar`(지지는 위로 4 띄움)입니다. 일간(일주 천간)은 `action.primary`
/// 2px 안쪽 테두리와 '나' 꼬리표(`tag.me`, 칸 밖 층이라 잘리지 않음)입니다. 글자 크기는 1.3배에서
/// 멈춥니다. 스크린리더는 표 이름 [tableLabel]과 열마다 [SajuPillarColumn.semanticLabel]을 읽습니다.
class SajuPillars extends StatelessWidget {
  /// 원국표를 만듭니다. [meLabel]은 '나' 꼬리표 글자입니다.
  const new({
    required this.hour,
    required this.day,
    required this.month,
    required this.year,
    required this.meLabel,
    required this.tableLabel,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('saju-pillars', {}, {
    'time-unknown',
    'loading',
  });

  /// 일간 칸 테두리를 찾는 테스트용 키.
  static const Key dayMasterKey = ValueKey('saju-pillars-day-master');

  /// '나' 꼬리표를 찾는 테스트용 키.
  static const Key meTagKey = ValueKey('saju-pillars-me');

  /// 열 사이(`columns.gap`).
  static const double columnGap = 6;

  /// 시주.
  final SajuPillarColumn hour;

  /// 일주(천간이 일간).
  final SajuPillarColumn day;

  /// 월주.
  final SajuPillarColumn month;

  /// 연주.
  final SajuPillarColumn year;

  /// '나' 꼬리표 글자.
  final String meLabel;

  /// 표 이름(스크린리더).
  final String tableLabel;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: OhaengCell.textScaleMax);
    final columns = [hour, day, month, year];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Semantics(
        container: true,
        label: tableLabel,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, column) in columns.indexed) ...[
              if (index > 0) const SizedBox(width: columnGap),
              Expanded(
                child: _PillarColumn(
                  column: column,
                  dayMaster: identical(column, day),
                  meLabel: meLabel,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillarColumn extends StatelessWidget {
  const new({
    required this.column,
    required this.dayMaster,
    required this.meLabel,
  });

  final SajuPillarColumn column;
  final bool dayMaster;
  final String meLabel;

  /// 라벨 줄 높이(라벨이 없어도 자리를 지켜 칸이 줄을 맞춤).
  static const double _labelRow = 26;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final stem = column.stem ?? const OhaengCell.empty();
    final branch = column.branch ?? const OhaengCell.empty();
    Widget label(Widget? child) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _labelRow),
      child: Center(child: child ?? const SizedBox.shrink()),
    );
    return Semantics(
      container: true,
      label: column.semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              column.header,
              textAlign: TextAlign.center,
              style: tokens.typography.captionMd.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: Space.s4),
          label(column.stemLabel),
          const SizedBox(height: Space.s4),
          if (dayMaster && column.stem != null)
            _DayMaster(meLabel: meLabel, child: stem)
          else
            stem,
          const SizedBox(height: 4),
          branch,
          const SizedBox(height: Space.s4),
          label(column.branchLabel),
        ],
      ),
    );
  }
}

/// 일간 칸: 안쪽 2px `action.primary` 테두리와 오른쪽 위 모서리에 겹친 '나' 꼬리표.
class _DayMaster extends StatelessWidget {
  const new({required this.meLabel, required this.child});

  final String meLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            key: SajuPillars.dayMasterKey,
            decoration: BoxDecoration(
              border: Border.all(
                color: context.tokens.colors.actionPrimary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
          ),
        ),
      ),
      PositionedDirectional(
        top: -8,
        end: -6,
        child: ExcludeSemantics(
          child: TagMe(meLabel, key: SajuPillars.meTagKey),
        ),
      ),
    ],
  );
}

/// 원국표 `loading`: 칸 모양 skeleton(네 기둥 × 천간·지지 칸, 라벨 자리는 짧은 막대).
///
/// [SkeletonBlock]의 `child`로 넣어 쓰면 지연·숨쉬기·스크린리더 라벨을 그대로 받습니다.
class SajuPillarsSkeleton extends StatelessWidget {
  /// skeleton을 만듭니다. [animated]가 false면 숨쉬지 않습니다(golden).
  const new({this.animated = true, super.key});

  /// 숨쉬기 여부.
  final bool animated;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 4; i++) ...[
        if (i > 0) const SizedBox(width: SajuPillars.columnGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SkeletonBone(
                  height: 12,
                  width: 28,
                  index: i,
                  animated: animated,
                ),
              ),
              const SizedBox(height: Space.s12),
              SkeletonBone(
                height: OhaengCell.pillarHeight,
                borderRadius: Radii.sm,
                index: i,
                animated: animated,
              ),
              const SizedBox(height: 4),
              SkeletonBone(
                height: OhaengCell.pillarHeight,
                borderRadius: Radii.sm,
                index: i + 1,
                animated: animated,
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
