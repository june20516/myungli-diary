import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 최소 터치 크기(px). 확인 창 버튼·다시 시도 모두 44입니다.
const double feedbackMinTarget = 44;

/// 확인 창 버튼과 오류 화면의 "다시 시도"에 쓰는 글자 버튼(`quiet` 모양).
///
/// 눌림은 글자 둘레에서만 번지는 `press.ink`이고 배경·테두리·그림자가 없습니다.
/// 키보드 확정(Enter·Space)과 초점을 받습니다. 동작이라 모서리는 `radius.md`입니다.
class FeedbackTextAction extends StatefulWidget {
  /// 글자 버튼을 만듭니다.
  const new({
    required this.label,
    required this.style,
    required this.onPressed,
    this.autofocus = false,
    super.key,
  });

  /// 버튼 글자.
  final String label;

  /// 글자 스타일(색 포함).
  final TextStyle style;

  /// 눌렀을 때.
  final VoidCallback onPressed;

  /// 열릴 때 처음 초점을 받을지.
  final bool autofocus;

  @override
  State<FeedbackTextAction> createState() => _FeedbackTextActionState();
}

class _FeedbackTextActionState extends State<FeedbackTextAction>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: InteractionPattern.pressInk.duration,
  );
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: pressInkReleaseDuration,
  )..addStatusListener(_onReleased);

  Alignment _origin = Alignment.center;

  void _onReleased(AnimationStatus status) {
    if (status == AnimationStatus.completed) _press.value = 0;
  }

  @override
  void dispose() {
    _press.dispose();
    _release.dispose();
    super.dispose();
  }

  void _down(TapDownDetails details) {
    final size = context.size ?? const Size.square(feedbackMinTarget);
    _origin = Alignment(
      details.localPosition.dx / size.width * 2 - 1,
      details.localPosition.dy / size.height * 2 - 1,
    );
    _release.value = 0;
    _press.forward(from: 0);
  }

  void _up() => _release.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          autofocus: widget.autofocus,
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _down,
            onTapUp: (_) {
              _up();
              widget.onPressed();
            },
            onTapCancel: _up,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: feedbackMinTarget,
                minHeight: feedbackMinTarget,
              ),
              child: animate(
                InteractionPattern.pressInk,
                t: _press,
                prefs: MotionPrefs.of(context),
                options: PatternOptions(
                  origin: _origin,
                  release: _release,
                  inkColor: widget.style.color ?? colors.textPrimary,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.s12,
                      vertical: Space.s8,
                    ),
                    child: Text(widget.label, style: widget.style),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
