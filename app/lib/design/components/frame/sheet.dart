import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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

/// 마지막 이동 뒤 이 시간이 지나 놓으면 멈춘 것으로 보아 속도를 0으로 칩니다.
const Duration _staleSample = Duration(milliseconds: 80);

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
    this.onDragCancel,
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

  /// 끌기가 취소됨(다른 인식기가 가져간 경우 등).
  final GestureDragCancelCallback? onDragCancel;

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
        // 스크롤할 수 없는 본문은 Scrollable이 드래그를 가져가지 않으므로 이 인식기가 받습니다.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: onDragUpdate,
          onVerticalDragEnd: onDragEnd,
          onVerticalDragCancel: onDragCancel,
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
                  Padding(
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
                  Flexible(child: child),
                ],
              ),
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

  /// iOS 같은 Bouncing 본문이 맨 위에서 밀려난 양. 시트가 그만큼 따라 내려가므로 본문은
  /// 같은 양만큼 되올려 이중으로 움직여 보이지 않게 합니다.
  double _bounce = 0;
  bool _scrollDragging = false;
  bool _dismissing = false;
  VelocityTracker _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
  Duration? _lastSample;
  final GlobalKey _frameKey = GlobalKey();
  final _HeadingClaim _headingClaim = _HeadingClaim();

  double get _snapCurve => Curves.easeOut.transform(_snap.value);

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  /// 끄는 위치·시각을 속도 추정기에 넣습니다(Flutter 스크롤과 같은 방식).
  void _track(DragUpdateDetails details) {
    final stamp = details.sourceTimeStamp;
    if (stamp == null) return;
    _tracker.addPosition(stamp, details.globalPosition);
    _lastSample = stamp;
  }

  /// 손을 떼는 순간의 아래 방향 속도(px/s). 마지막 이동 뒤 멈췄다 놓으면 0입니다.
  double _releaseVelocity() {
    final last = _lastSample;
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (last != null && now - last > _staleSample) return 0;
    return _tracker.getVelocity().pixelsPerSecond.dy;
  }

  void _resetTracking() {
    _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
    _lastSample = null;
    _scrollDragging = false;
  }

  /// 본문 바깥(시트 프레임)에서 받은 드래그: 스크롤할 수 없는 본문.
  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    _snap.stop();
    _track(details);
    setState(() => _drag = math.max(0, _drag + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) =>
      _finishDrag(details.velocity.pixelsPerSecond.dy);

  /// 취소되면 놓은 것처럼 제자리로 돌아갑니다(닫지 않음).
  void _onDragCancel() {
    if (_dismissing) return;
    _resetTracking();
    _settleBack();
  }

  void _settleBack() {
    _dragFrom = _drag;
    _snap.forward(from: 0);
  }

  /// 긴 스크롤 본문: 맨 위에서 넘치는 양을 시트 끌기로 씁니다.
  ///
  /// - Clamping 계열(Android): `OverscrollNotification`.
  /// - Bouncing 계열(iOS): `pixels < minScrollExtent`인 스크롤 갱신.
  /// 본문이 스크롤 중이면(맨 위가 아니면) 스크롤이 먼저입니다.
  bool _onScroll(ScrollNotification n) {
    if (_dismissing || n.depth != 0 || n.metrics.axis != Axis.vertical) {
      return false;
    }
    final metrics = n.metrics;
    switch (n) {
      case OverscrollNotification(:final dragDetails?, :final overscroll)
          when overscroll < 0:
        _snap.stop();
        _scrollDragging = true;
        _track(dragDetails);
        setState(() => _drag += -overscroll);
      case ScrollUpdateNotification()
          when metrics.pixels < metrics.minScrollExtent:
        final amount = metrics.minScrollExtent - metrics.pixels;
        if (n.dragDetails != null) {
          _snap.stop();
          _scrollDragging = true;
          _track(n.dragDetails!);
        } else if (_scrollDragging) {
          // 손을 뗀 순간: 이후의 되돌아옴은 본문 bounce가 끌고 가고 시트가 따라갑니다.
          _scrollDragging = false;
          if (_shouldDismiss(amount, _releaseVelocity())) {
            unawaited(_dismiss());
            return false;
          }
        }
        setState(() {
          _drag = amount;
          _bounce = amount;
        });
      case ScrollUpdateNotification() when _bounce > 0:
        // bounce가 끝나 제자리로 돌아옴.
        _bounce = 0;
        _drag = 0;
        setState(() {});
      case ScrollUpdateNotification(:final scrollDelta?, :final dragDetails?)
          when _drag > 0 && scrollDelta > 0:
        // 시트를 올리는 중: 본문이 함께 스크롤되지 않게 올린 만큼 되돌립니다.
        //
        // 본문은 임의 위젯이라 스크롤 물리를 가로챌 수 없어 위치를 직접 보정합니다.
        // `correctBy`는 Flutter 문서상 레이아웃 중에 쓰도록 만든 API이고 갱신 알림을
        // 내지 않으므로, 위치를 듣는 리스너는 한 프레임 늦게 보정된 값을 봅니다.
        // 이 동작은 테스트('android: 시트를 올리는 동안 본문은 스크롤되지 않습니다')가 고정합니다.
        final absorbed = math.min(scrollDelta, _drag);
        Scrollable.maybeOf(n.context!)?.position.correctBy(-absorbed);
        _track(dragDetails);
        setState(() => _drag -= absorbed);
      case ScrollEndNotification() when _scrollDragging && _drag > 0:
        final velocity =
            n.dragDetails?.velocity.pixelsPerSecond.dy ?? _releaseVelocity();
        _scrollDragging = false;
        _finishDrag(velocity);
      default:
        break;
    }
    return false;
  }

  bool _shouldDismiss(double distance, double velocity) {
    final sheetHeight = _frameKey.currentContext?.size?.height ?? 0;
    return distance > sheetHeight * _dismissFraction ||
        velocity > _dismissVelocity;
  }

  void _finishDrag(double velocity) {
    _resetTracking();
    if (_shouldDismiss(_drag, velocity)) {
      unawaited(_dismiss());
      return;
    }
    _settleBack();
  }

  /// 맨 위 시트를 닫습니다. `PopScope`가 막아 닫히지 않으면 제자리로 돌아옵니다.
  Future<void> _dismiss() async {
    _dismissing = true;
    // `maybePop`은 `PopScope`가 막아도 true를 주므로, route가 실제로 빠졌는지 봅니다.
    await Navigator.of(context).maybePop();
    if (!mounted || !widget.route.isActive) return;
    _dismissing = false;
    // 본문이 bounce로 되돌아오는 중이면 그 값이 시트를 끌고 가므로 따로 움직이지 않습니다.
    if (_bounce == 0) _settleBack();
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
          onDragCancel: _onDragCancel,
          child: _HeadingClaimScope(
            claim: _headingClaim,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              // Bouncing 본문이 밀려난 만큼 되올려, 시트 이동과 이중으로 보이지 않게 합니다.
              child: _BounceCompensation(
                bounce: _bounce,
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

/// iOS bounce로 본문이 [bounce]만큼 밀려난 것을 되올립니다.
///
/// 본문 전체를 위로 옮기면 아래 [bounce]만큼이 비므로, 본문의 높이를 그만큼 늘려 아래 끝을
/// 원래 자리에 둡니다(띠가 생기지 않음). 높이가 정해진 경우에만 늘리고, 시트 높이는
/// 부모가 정한 범위를 넘지 않습니다.
class _BounceCompensation extends StatelessWidget {
  const new({required this.bounce, required this.child});

  final double bounce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 구조는 항상 같게 둡니다(본문의 스크롤 상태가 유지되도록).
    return LayoutBuilder(
      builder: (context, constraints) => OverflowBox(
        alignment: Alignment.topCenter,
        fit: OverflowBoxFit.deferToChild,
        maxHeight: constraints.hasBoundedHeight
            ? constraints.maxHeight + bounce
            : null,
        child: Transform.translate(offset: Offset(0, -bounce), child: child),
      ),
    );
  }
}
