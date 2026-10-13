import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 시트 높이 변형.
enum SheetSize {
  /// 화면 60%까지: 풀이·근거·그날·공유 미리보기처럼 짧은 내용.
  half,

  /// 위 안전 영역 + 12px까지: 긴 목록·설정 안쪽.
  full,
}

/// 시트 비율(half)과 위 간격(full), 손잡이 크기 등 `frame.json` `sheet` 값.
const double sheetHalfFraction = 0.6;

/// full 시트가 위 안전 영역 아래로 비워 두는 간격(px).
const double sheetFullTopGap = 12;

/// 손잡이 너비(px).
const double sheetHandleWidth = 36;

/// 손잡이 높이(px).
const double sheetHandleHeight = 4;

/// 끌어내려 닫는 기준: 시트 높이의 이 비율 이상.
const double _dismissFraction = 0.25;

/// 끌어내려 닫는 기준 속도(px/s).
const double _dismissVelocity = 700;

/// [size]의 시트가 가질 수 있는 최대 높이.
double sheetMaxHeight(BuildContext context, SheetSize size) {
  final screen = MediaQuery.sizeOf(context).height;
  return switch (size) {
    SheetSize.half => screen * sheetHalfFraction,
    SheetSize.full =>
      screen - MediaQuery.viewPaddingOf(context).top - sheetFullTopGap,
  };
}

/// 시트 틀: 위 모서리 `radius.xl`, `bg.sheet`, 손잡이, 안쪽 여백.
///
/// 열고 닫는 움직임은 [showMyungliSheet]의 route가 입힙니다. 이 위젯은 모양만 정합니다.
class MyungliSheetFrame extends StatelessWidget {
  /// 시트 틀을 만듭니다.
  const new({
    required this.maxHeight,
    required this.child,
    this.semanticLabel,
    this.onDragUpdate,
    this.onDragEnd,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'sheet',
    {'half', 'full'},
    {'opening', 'closing', 'stacked'},
  );

  /// 시트가 가질 수 있는 최대 높이.
  final double maxHeight;

  /// 시트 내용. 길면 내용이 스스로 스크롤합니다.
  final Widget child;

  /// 스크린리더가 읽는 시트 제목.
  final String? semanticLabel;

  /// 손잡이를 끄는 중.
  final GestureDragUpdateCallback? onDragUpdate;

  /// 손잡이를 놓음.
  final GestureDragEndCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.bgSheet,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Radii.xl),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Space.s20,
              0,
              Space.s20,
              Space.s24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: onDragUpdate,
                  onVerticalDragEnd: onDragEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.s8),
                    child: Center(
                      child: DecoratedBox(
                        key: const ValueKey('sheet.handle'),
                        decoration: BoxDecoration(
                          color: colors.line,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                        child: const SizedBox(
                          width: sheetHandleWidth,
                          height: sheetHandleHeight,
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 하프·풀 시트를 새 route로 엽니다.
///
/// 시트 안에서 다시 열면 `sheet.stack`으로 위에 쌓이고 아래 층이 물러납니다.
/// 뒤로 가기·끌어내리기는 맨 위 시트 하나만, 바깥(덮개)은 쌓인 시트 모두 닫습니다.
Future<T?> showMyungliSheet<T>(
  BuildContext context, {
  required SheetSize size,
  required WidgetBuilder builder,
  String? semanticLabel,
}) {
  return Navigator.of(context).push<T>(
    _SheetRoute<T>(size: size, builder: builder, semanticLabel: semanticLabel),
  );
}

class _SheetRoute<T> extends PopupRoute<T> {
  new({required this.size, required this.builder, this.semanticLabel});

  final SheetSize size;
  final WidgetBuilder builder;
  final String? semanticLabel;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => InteractionPattern.sheetEnter.duration;

  @override
  Duration get reverseTransitionDuration =>
      InteractionPattern.sheetExit.duration;

  // 아래 층이 물러나는 것은 시트가 시트 위에 쌓일 때뿐입니다.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is _SheetRoute;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _SheetPage<T>(
      route: this,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _SheetPage<T> extends StatefulWidget {
  const new({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
  });

  final _SheetRoute<T> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;

  @override
  State<_SheetPage<T>> createState() => _SheetPageState<T>();
}

class _SheetPageState<T> extends State<_SheetPage<T>>
    with SingleTickerProviderStateMixin {
  late final Animation<double> _exit = ReverseAnimation(widget.animation);
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: Motion.short,
  )..addListener(() => setState(() => _drag = _dragFrom * (1 - _snapCurve)));

  double _drag = 0;
  double _dragFrom = 0;
  final GlobalKey _frameKey = GlobalKey();

  double get _snapCurve => Curves.easeOut.transform(_snap.value);

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _snap.stop();
    setState(() => _drag = math.max(0, _drag + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final sheetHeight = _frameKey.currentContext?.size?.height ?? 0;
    if (_drag > sheetHeight * _dismissFraction || velocity > _dismissVelocity) {
      Navigator.of(context).pop();
      return;
    }
    _dragFrom = _drag;
    _snap.forward(from: 0);
  }

  void _dismissAll() {
    Navigator.of(context).popUntil((route) => route is! _SheetRoute);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = MotionPrefs.of(context);
    final maxHeight = sheetMaxHeight(context, widget.route.size);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final exiting = widget.animation.status == AnimationStatus.reverse;
        final pattern = exiting
            ? InteractionPattern.sheetExit
            : InteractionPattern.sheetEnter;
        final t = exiting ? _exit : widget.animation;
        final frame = MyungliSheetFrame(
          key: _frameKey,
          maxHeight: maxHeight,
          semanticLabel: widget.route.semanticLabel,
          onDragUpdate: _onDragUpdate,
          onDragEnd: _onDragEnd,
          child: Builder(builder: widget.route.builder),
        );
        final sheet = animate(
          InteractionPattern.sheetStack,
          t: widget.secondaryAnimation,
          prefs: prefs,
          options: const PatternOptions(stackLayer: StackLayer.sheet),
          child: frame,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                label: l10n.sheetDismiss,
                onTap: _dismissAll,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissAll,
                    child: KeyedSubtree(
                      key: const ValueKey('sheet.scrim'),
                      child: animateScrim(pattern, t: t, prefs: prefs),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                // 끌어내린 만큼은 닫히는 동안 0으로 풀립니다.
                offset: Offset(0, _drag * widget.animation.value),
                child: animate(pattern, t: t, prefs: prefs, child: sheet),
              ),
            ),
          ],
        );
      },
    );
  }
}
