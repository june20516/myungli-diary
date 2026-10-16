import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

/// 버튼 글자 자리의 점(`loading.breathe`). 줄 사이 150ms씩 어긋나 숨 쉽니다.
///
/// `primary-button`과 `social-login-button`이 함께 씁니다.
class BreathingDots extends StatefulWidget {
  /// 점 [count]개를 [color]로 그립니다. [animated]가 false면 정지 상태입니다.
  const new({
    required this.color,
    required this.animated,
    required this.count,
    required this.size,
    required this.gap,
    super.key,
  });

  /// 버튼·줄이 함께 쓰는 점 개수(`action.json` `loading.dots.count`).
  static const int standardCount = 3;

  /// 버튼·줄이 함께 쓰는 점 지름.
  static const double standardSize = 6;

  /// 버튼·줄이 함께 쓰는 점 사이 간격.
  static const double standardGap = 6;

  /// 점 색.
  final Color color;

  /// false면 숨 쉬지 않고 정지 상태로 그립니다.
  final bool animated;

  /// 점 개수.
  final int count;

  /// 점 지름.
  final double size;

  /// 점 사이 간격.
  final double gap;

  @override
  State<BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<BreathingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: InteractionPattern.loadingBreathe.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animated) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(BreathingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated) didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = MotionPrefs.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: widget.gap,
      children: [
        for (var i = 0; i < widget.count; i++)
          animate(
            InteractionPattern.loadingBreathe,
            t: _controller,
            prefs: prefs,
            options: PatternOptions(index: i),
            child: SizedBox.square(
              dimension: widget.size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
