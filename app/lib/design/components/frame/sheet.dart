import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
  // 시트 안에서 여는 시트는 아래 시트의 덮개를 그대로 쓰고 자기 덮개는 더하지 않습니다.
  final underSheet = ModalRoute.of(context) is _SheetRoute;
  return Navigator.of(context).push<T>(
    _SheetRoute<T>(
      size: size,
      builder: builder,
      semanticLabel: semanticLabel,
      underSheet: underSheet,
    ),
  );
}

/// 시트가 시트 위에 쌓이는 동안 아래 화면에 걸 `sheet.stack` 진행(`screenBelow`).
final ValueNotifier<Animation<double>> _screenBelowProgress =
    ValueNotifier<Animation<double>>(kAlwaysDismissedAnimation);

/// 화면 셸이 화면 내용을 감싸 두면, 시트가 시트 위에 쌓일 때 화면이 0.92배·밝기 0.9로 물러납니다.
///
/// 구조는 항상 같고(내용의 상태가 유지됨) 쌓이지 않을 때는 진행 0이라 아무것도 바꾸지 않습니다.
class SheetScreenBelow extends StatelessWidget {
  /// 화면 내용을 감쌉니다.
  const new({required this.child, super.key});

  /// 화면 내용.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Animation<double>>(
      valueListenable: _screenBelowProgress,
      builder: (context, progress, child) => animate(
        InteractionPattern.sheetStack,
        t: progress,
        prefs: MotionPrefs.of(context),
        child: child!,
      ),
      child: child,
    );
  }
}

/// 시트 안 첫 제목. 시트가 열리면 스크린리더 초점이 여기로 옵니다(`focusOnOpen: first-heading`).
///
/// 시트 안에서 이 위젯을 여러 개 쓰면 먼저 만들어진 하나만 초점을 받습니다. 쓰지 않으면
/// 시트 이름([showMyungliSheet]의 `semanticLabel`)만 알려지고 초점은 플랫폼 기본을 따릅니다.
class SheetHeading extends StatefulWidget {
  /// 제목을 header 의미로 감쌉니다.
  const new({required this.child, super.key});

  /// 제목 위젯.
  final Widget child;

  @override
  State<SheetHeading> createState() => _SheetHeadingState();
}

class _SheetHeadingState extends State<SheetHeading> {
  @override
  void initState() {
    super.initState();
    final claim = context
        .getInheritedWidgetOfExactType<_HeadingClaimScope>()
        ?.claim;
    if (claim == null || claim.taken) return;
    claim.taken = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      Semantics(header: true, child: widget.child);
}

class _HeadingClaim {
  bool taken = false;
}

class _HeadingClaimScope extends InheritedWidget {
  const new({required this.claim, required super.child});

  final _HeadingClaim claim;

  @override
  bool updateShouldNotify(_HeadingClaimScope oldWidget) => false;
}

/// 시트 안 스크롤은 늘어나는 효과 없이 맨 위·아래에서 멈춥니다(끌어내리기와 겹치지 않게).
class _SheetScrollBehavior extends ScrollBehavior {
  const new();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _SheetRoute<T> extends PopupRoute<T> {
  new({
    required this.size,
    required this.builder,
    required this.underSheet,
    this.semanticLabel,
  });

  final SheetSize size;
  final bool underSheet;
  final WidgetBuilder builder;
  final String? semanticLabel;

  @override
  void install() {
    super.install();
    if (underSheet) _screenBelowProgress.value = animation!;
  }

  @override
  void dispose() {
    final progress = animation;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(_screenBelowProgress.value, progress)) {
        _screenBelowProgress.value = kAlwaysDismissedAnimation;
      }
    });
    super.dispose();
  }

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
  final _HeadingClaim _headingClaim = _HeadingClaim();

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

  void _onDragEnd(DragEndDetails details) =>
      _finishDrag(details.velocity.pixelsPerSecond.dy);

  /// 본문이 맨 위일 때 아래로 끄는 것은 시트가, 그 밖에는 스크롤이 받습니다.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification && n.dragDetails != null) {
      if (n.overscroll < 0) {
        _snap.stop();
        setState(() => _drag += -n.overscroll);
      }
    } else if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        _drag > 0 &&
        (n.scrollDelta ?? 0) > 0) {
      setState(() => _drag = math.max(0, _drag - n.scrollDelta!));
    } else if (n is ScrollEndNotification && _drag > 0) {
      _finishDrag(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  void _finishDrag(double velocity) {
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
          child: _HeadingClaimScope(
            claim: _headingClaim,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ScrollConfiguration(
                behavior: const _SheetScrollBehavior(),
                child: Builder(builder: widget.route.builder),
              ),
            ),
          ),
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
            if (widget.route.underSheet)
              // 덮개는 아래 시트의 것을 쓰고, 바깥 누르기만 이 층에서 받습니다.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissAll,
                  child: const SizedBox.expand(),
                ),
              )
            else
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
