import 'package:flutter/material.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 눌림이 글자 둘레에서만 번지는 `press.ink`를 입힌 누르는 자리.
///
/// `term-token`과 `depth-link`가 함께 씁니다. 배경·테두리·그림자가 없고, 키보드 확정
/// (Enter·Space)과 초점을 받습니다. 눌리는 영역을 위아래로 넓히는 `VerticalHitSlop`은
/// 판정이 바깥 조상에서 막히지 않도록 쓰는 쪽이 가장 바깥에 둡니다.
class PressInkTarget extends StatefulWidget {
  /// 누르는 자리를 만듭니다.
  const new({
    required this.semanticLabel,
    required this.onTap,
    required this.borderRadius,
    required this.child,
    this.link = false,
    this.inkColor,
    super.key,
  });

  /// 스크린리더 라벨.
  final String semanticLabel;

  /// 눌렀을 때.
  final VoidCallback onTap;

  /// 얼룩을 자를 모서리.
  final BorderRadius borderRadius;

  /// true면 링크, false면 버튼으로 읽습니다.
  final bool link;

  /// 얼룩 색(그 컴포넌트의 글자색). 없으면 `text.primary`.
  final Color? inkColor;

  /// 눌리는 모습.
  final Widget child;

  @override
  State<PressInkTarget> createState() => _PressInkTargetState();
}

class _PressInkTargetState extends State<PressInkTarget>
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
    final size = context.size ?? const Size.square(44);
    _origin = Alignment(
      size.width == 0 ? 0 : details.localPosition.dx / size.width * 2 - 1,
      size.height == 0 ? 0 : details.localPosition.dy / size.height * 2 - 1,
    );
    _release.value = 0;
    _press.forward(from: 0);
  }

  void _up() => _release.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: !widget.link,
      link: widget.link,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _down,
            onTapUp: (_) {
              _up();
              widget.onTap();
            },
            onTapCancel: _up,
            child: animate(
              InteractionPattern.pressInk,
              t: _press,
              prefs: MotionPrefs.of(context),
              options: PatternOptions(
                origin: _origin,
                release: _release,
                inkColor: widget.inkColor ?? context.tokens.colors.textPrimary,
                borderRadius: widget.borderRadius,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
