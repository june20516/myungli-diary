import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 불러오는 중 자리(`skeleton`). 스피너 대신 [SkeletonBone]이 숨 쉽니다.
///
/// 300ms 안에 끝나는 불러오기에는 보이지 않도록 [delay] 뒤에야 그립니다.
/// [child]를 주면 실제 올 요소와 같은 자리·크기·반경으로 짠 [SkeletonBone] 배치를 쓰고,
/// 없으면 글줄 [lines]개를 그립니다(글자 줄 높이의 60%, 마지막 줄은 너비 60%). 글줄의 줄
/// 높이는 [lineStyle]에서 구하고, 없으면 `type.body.ui`입니다. 문장 본문(`type.sentence.body`)
/// 자리처럼 실제 올 글자와 줄 높이를 맞출 때 줍니다(명세에 올릴지는 #211에서 판단).
class SkeletonBlock extends StatefulWidget {
  /// 자리를 만듭니다.
  const new({
    this.child,
    this.lines = 3,
    this.lineStyle,
    this.delay = defaultDelay,
    this.animated = true,
    super.key,
  }) : assert(child != null || lines > 0, '내용이 없으면 글줄이 하나 이상이어야 합니다.');

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('skeleton', {}, {'loading'});

  /// 보이기 전에 기다리는 시간. 이보다 빨리 끝나면 skeleton은 나오지 않습니다.
  static const Duration defaultDelay = Duration(milliseconds: 300);

  /// 직접 짠 [SkeletonBone] 배치. 없으면 글줄을 그립니다.
  final Widget? child;

  /// [child]가 없을 때 그릴 글줄 수.
  final int lines;

  /// [child]가 없을 때 글줄 높이를 정할 글자 스타일. 없으면 `type.body.ui`입니다.
  final TextStyle? lineStyle;

  /// 보이기 전 대기. golden·테스트에서는 [Duration.zero]를 줍니다.
  final Duration delay;

  /// false면 숨쉬지 않고 정지 상태로 그립니다(golden).
  final bool animated;

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
    if (!_visible) return const SizedBox.shrink();
    // 명세 role progressbar의 불확정 로딩은 progressBar가 값·범위를 요구해
    // loadingSpinner로 둡니다(값 검사 없음).
    return Semantics(
      role: SemanticsRole.loadingSpinner,
      label: AppLocalizations.of(context).skeletonLabel,
      child: ExcludeSemantics(
        child:
            widget.child ??
            _Lines(
              lines: widget.lines,
              style: widget.lineStyle,
              animated: widget.animated,
            ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const new({required this.lines, required this.style, required this.animated});

  final int lines;
  final TextStyle? style;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? context.tokens.typography.bodyUi;
    final fontSize = MediaQuery.textScalerOf(context)
        .scale(style.fontSize ?? 14);
    final lineHeight = fontSize * (style.height ?? 1.5);
    final boneHeight = lineHeight * 0.6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++)
          Padding(
            padding: EdgeInsets.only(bottom: lineHeight - boneHeight),
            child: FractionallySizedBox(
              widthFactor: i == lines - 1 ? 0.6 : 1,
              child: SkeletonBone(
                height: boneHeight,
                borderRadius: Radii.xs,
                index: i,
                animated: animated,
              ),
            ),
          ),
      ],
    );
  }
}
