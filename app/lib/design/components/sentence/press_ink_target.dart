import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/press_ink_state.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 눌림이 글자 둘레에서만 번지는 `press.ink`를 입힌 누르는 자리.
///
/// `term-token`과 `depth-link`가 함께 씁니다. 배경·테두리·그림자가 없고, 키보드 확정
/// (Enter·Space)과 초점을 받습니다. 눌리는 영역을 위아래로 넓히는 `VerticalHitSlop`은
/// 판정이 바깥 조상에서 막히지 않도록 쓰는 쪽이 가장 바깥에 둡니다.
///
/// 제공자 가이드가 눌림 모양을 따로 정한 곳(LINE 버튼의 덮개)은 [PressInkTarget.pressed]로
/// 얼룩 대신 눌림 상태를 받아 직접 그립니다. 의미·초점·키보드 확정은 같습니다.
class PressInkTarget extends StatefulWidget {
  /// 누르는 자리를 만듭니다.
  const new({
    required this.semanticLabel,
    required this.onTap,
    required this.borderRadius,
    required Widget this.child,
    this.link = false,
    this.expanded,
    this.identifier,
    this.hint,
    this.inkColor,
    this.customActions = const {},
    super.key,
  }) : builder = null;

  /// `press.ink` 얼룩 없이, 눌린 동안 [builder]에 `pressed: true`를 주는 누르는 자리를
  /// 만듭니다.
  const new pressed({
    required this.semanticLabel,
    required this.onTap,
    required PressedWidgetBuilder this.builder,
    this.link = false,
    this.expanded,
    this.identifier,
    this.hint,
    this.customActions = const {},
    super.key,
  }) : child = null,
       borderRadius = BorderRadius.zero,
       inkColor = null;

  /// 스크린리더 라벨.
  final String semanticLabel;

  /// 눌렀을 때. null이면 누를 수 없는 꺼진 자리입니다(눌림 없이 그대로 보이고, 위젯 트리는
  /// 켜졌을 때와 같아 전환에서 눌림 잉크가 끊기지 않습니다).
  final VoidCallback? onTap;

  /// 얼룩을 자를 모서리.
  final BorderRadius borderRadius;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// 스크린리더 힌트(누르면 무엇이 되는지). 없으면 읽지 않습니다.
  final String? hint;

  /// true면 링크, false면 버튼으로 읽습니다.
  final bool link;

  /// 펼침 상태를 읽어 줍니다. 펼쳐지는 대상이 아니면 null(상태 없음)입니다.
  final bool? expanded;

  /// 얼룩 색(그 컴포넌트의 글자색). 없으면 `text.primary`.
  final Color? inkColor;

  /// 스크린리더의 추가 동작(이름 → 동작). 안에 따로 눌리는 것(카드 안 태그 칩 등)이 있어도
  /// 이 자리 전체를 한 덩어리로 읽으므로, 그 동작을 여기에 올려 스크린리더에서도 닿게 합니다.
  final Map<CustomSemanticsAction, VoidCallback> customActions;

  /// 눌리는 모습. [PressInkTarget.pressed]에서는 null입니다.
  final Widget? child;

  /// 눌림 상태로 모습을 그리는 함수. 기본 생성자에서는 null입니다.
  final PressedWidgetBuilder? builder;

  @override
  State<PressInkTarget> createState() => _PressInkTargetState();
}

/// 눌림 상태([pressed])로 모습을 그리는 함수.
typedef PressedWidgetBuilder = Widget Function({required bool pressed});

class _PressInkTargetState extends State<PressInkTarget>
    with TickerProviderStateMixin, PressInkState<PressInkTarget> {
  /// [PressInkTarget.pressed]에서 지금 눌려 있는지.
  bool _pressed = false;

  @override
  void didUpdateWidget(PressInkTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 눌린 채 꺼지면 제스처 인식기가 사라지며 취소가 build 중에 옵니다. 눌림 상태를 먼저
    // 풀어 두어 그 취소가 setState를 부르지 않게 하고, 꺼진 자리에 눌림이 남지 않게 합니다.
    if (oldWidget.onTap != null && widget.onTap == null && _pressed) {
      _pressed = false;
    }
  }

  void _down(TapDownDetails details) {
    if (widget.builder == null) {
      pressInkDown(details);
    } else {
      setState(() => _pressed = true);
    }
  }

  void _up() {
    if (widget.builder == null) {
      pressInkUp();
    } else if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final builder = widget.builder;
    return Semantics(
      container: true,
      enabled: onTap != null,
      button: !widget.link,
      link: widget.link,
      expanded: widget.expanded,
      identifier: widget.identifier,
      label: widget.semanticLabel,
      hint: widget.hint,
      onTap: onTap,
      customSemanticsActions: widget.customActions.isEmpty
          ? null
          : widget.customActions,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: onTap != null,
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onTap?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onTap == null ? null : _down,
            onTapUp: onTap == null
                ? null
                : (_) {
                    _up();
                    onTap();
                  },
            onTapCancel: onTap == null ? null : _up,
            child: builder != null
                ? builder(pressed: _pressed)
                : animate(
                    InteractionPattern.pressInk,
                    t: pressInk,
                    prefs: MotionPrefs.of(context),
                    options: PatternOptions(
                      origin: pressInkOrigin,
                      release: pressInkRelease,
                      inkColor:
                          widget.inkColor ?? context.tokens.colors.textPrimary,
                      borderRadius: widget.borderRadius,
                    ),
                    child: widget.child!,
                  ),
          ),
        ),
      ),
    );
  }
}
