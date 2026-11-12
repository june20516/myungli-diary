import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/text/line_height.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 불러오는 중 자리(`skeleton`). 스피너 대신 [SkeletonBone]이 숨 쉽니다.
///
/// 300ms 안에 끝나는 불러오기에는 보이지 않도록 [delay] 뒤에야 그립니다.
/// [child]는 그 자리 컴포넌트들의 `states.loading.skeleton` 뼈를 실제 배치(화면 좌우 여백,
/// 섹션 제목, 섹션 사이 간격)대로 놓은 것입니다(결정 V66). 여백 없이 글줄만 쌓은 공용
/// skeleton은 두지 않습니다(F-011). 뼈 모양은 [SkeletonTextLines](글줄), [SkeletonCard](카드),
/// [SkeletonChip](칩), [SkeletonBone](그 밖의 자리)으로 짭니다.
class SkeletonBlock extends StatefulWidget {
  /// 자리를 만듭니다.
  const new({
    required this.child,
    this.delay = defaultDelay,
    this.reserveSpace = false,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('skeleton', {}, {'loading'});

  /// 보이기 전에 기다리는 시간. 이보다 빨리 끝나면 skeleton은 나오지 않습니다.
  static const Duration defaultDelay = Duration(milliseconds: 300);

  /// 실제 올 요소와 같은 자리·크기·반경으로 짠 뼈 배치.
  final Widget child;

  /// 보이기 전 대기. golden·테스트에서는 [Duration.zero]를 줍니다.
  final Duration delay;

  /// true면 [delay] 동안에도 뼈 크기만큼 자리를 비워 둡니다(그리지도 읽지도 않음). 스크롤 끝
  /// 섹션처럼 자리가 0에서 자라면 끝에 닿은 스크롤 위치가 어긋나는 곳에서 씁니다(#936).
  /// "300ms 안이면 보이지 않음" 규칙은 그대로입니다.
  final bool reserveSpace;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock> {
  Timer? _timer;
  late bool _visible = widget.delay == Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_visible) {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return widget.reserveSpace
          ? Visibility(
              visible: false,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: widget.child,
            )
          : const SizedBox.shrink();
    }
    // 명세 role progressbar의 불확정 로딩은 progressBar가 값·범위를 요구해
    // loadingSpinner로 둡니다(값 검사 없음).
    return Semantics(
      role: SemanticsRole.loadingSpinner,
      label: AppLocalizations.of(context).skeletonLabel,
      child: ExcludeSemantics(child: widget.child),
    );
  }
}

/// 글줄 뼈(`skeleton.parts.textLine`). 실제 올 글자 [style]의 줄 높이마다 그 60% 높이
/// 뼈를 줄 가운데에 둡니다. 반경은 `radius.xs`입니다.
///
/// [widthFactor]는 계약 뼈의 `width`(백분율)입니다. 주지 않으면 마지막 줄만 60%
/// (`lastLineWidth`)이고 나머지 줄은 부모 폭을 채웁니다. [style]이 없으면
/// `type.body.ui`입니다(`textLine.type.default`). 글자 배율을 따라 실제 글자와 같은 높이가
/// 됩니다.
class SkeletonTextLines extends StatelessWidget {
  /// 글줄 [lines]개를 만듭니다.
  const new({
    this.lines = 1,
    this.style,
    this.widthFactor,
    this.index = 0,
    this.animated = true,
    super.key,
  }) : assert(lines > 0, '글줄은 하나 이상이어야 합니다.'),
       assert(
         widthFactor == null || (widthFactor > 0 && widthFactor <= 1),
         '폭 비율은 0보다 크고 1 이하입니다.',
       );

  /// 줄 수.
  final int lines;

  /// 실제 올 글자 스타일. 없으면 `type.body.ui`입니다.
  final TextStyle? style;

  /// 모든 줄의 폭 비율(계약 `width`). 없으면 마지막 줄만 [lastLineWidthFactor]입니다.
  final double? widthFactor;

  /// 첫 줄의 숨쉬기 순서. 줄마다 하나씩 늘어 150ms씩 어긋납니다.
  final int index;

  /// false면 숨쉬지 않고 정지 상태로 그립니다(golden).
  final bool animated;

  /// 마지막 줄 폭 비율(`textLine.lastLineWidth` 60%).
  static const double lastLineWidthFactor = 0.6;

  /// 줄 높이에 대한 뼈 높이 비율(`textLine.height` "글자 줄 높이의 60%").
  static const double heightFactor = 0.6;

  /// [style]을 주지 않았을 때 글줄 높이의 기준(`type.body.ui`).
  static TextStyle defaultStyleOf(BuildContext context) =>
      context.tokens.typography.bodyUi;

  @override
  Widget build(BuildContext context) {
    final lineHeight = lineHeightOf(
      style ?? defaultStyleOf(context),
      MediaQuery.textScalerOf(context),
    );
    final boneHeight = lineHeight * heightFactor;
    final inset = (lineHeight - boneHeight) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: inset),
            child: FractionallySizedBox(
              widthFactor:
                  widthFactor ?? (i == lines - 1 ? lastLineWidthFactor : 1),
              child: SkeletonBone(
                height: boneHeight,
                borderRadius: Radii.xs,
                index: index + i,
                animated: animated,
              ),
            ),
          ),
      ],
    );
  }
}

/// 칩 뼈(`skeleton.parts.chip`). 알약(`radius.full`) 모양이고 높이는 실제 칩과 같습니다.
class SkeletonChip extends StatelessWidget {
  /// 칩 하나를 만듭니다.
  const new({
    required this.width,
    required this.height,
    this.index = 0,
    this.animated = true,
    super.key,
  });

  /// 너비(계약 뼈의 `width`).
  final double width;

  /// 높이(실제 칩 높이).
  final double height;

  /// 숨쉬기 순서.
  final int index;

  /// false면 정지 상태로 그립니다(golden).
  final bool animated;

  @override
  Widget build(BuildContext context) => SkeletonBone(
    width: width,
    height: height,
    borderRadius: Radii.full,
    index: index,
    animated: animated,
  );
}

/// 카드 뼈(`skeleton.parts.card`). 실제 카드와 같은 바탕(`bg.sheet`), 반경(`radius.lg`),
/// 안쪽 여백([padding])에 안쪽 뼈 [child]를 담습니다. 카드 자체는 숨쉬지 않습니다.
class SkeletonCard extends StatelessWidget {
  /// 카드 뼈를 만듭니다.
  const new({required this.padding, required this.child, super.key});

  /// 실제 카드와 같은 안쪽 여백.
  final EdgeInsetsGeometry padding;

  /// 카드 안 뼈.
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.tokens.colors.bgSheet,
      borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
    ),
    child: Padding(padding: padding, child: child),
  );
}
