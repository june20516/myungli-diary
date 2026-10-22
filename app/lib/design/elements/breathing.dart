import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

/// [child] 전체에 먹 숨쉬기(`loading.breathe`)를 입힙니다.
///
/// 처리 중인 줄 전체(떼는 중인 `social-login-button` `connected`)나 불러오는 중인 빈 카드
/// (`account-choice` `loading`)처럼 자리 하나가 통째로 숨쉴 때 씁니다. 글줄 자리 하나는
/// `SkeletonBone`이 같은 패턴으로 그립니다.
class Breathing extends StatefulWidget {
  /// 숨쉬는 자리를 만듭니다.
  const new({
    required this.child,
    this.index = 0,
    this.animated = true,
    super.key,
  });

  /// 숨쉬는 대상.
  final Widget child;

  /// 줄 순서. 줄마다 150ms씩 어긋납니다.
  final int index;

  /// false면 움직이지 않고 정지 상태로 그립니다(golden 등).
  final bool animated;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: InteractionPattern.loadingBreathe.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Breathing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated) _sync();
  }

  void _sync() {
    if (widget.animated) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => animate(
    InteractionPattern.loadingBreathe,
    t: _controller,
    prefs: MotionPrefs.of(context),
    options: PatternOptions(index: widget.index),
    child: widget.child,
  );
}
