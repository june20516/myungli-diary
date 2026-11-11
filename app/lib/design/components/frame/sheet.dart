import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

/// 시트 맨 위 핸들 자리 높이(px). `frame.json` `sheet.parts.handleArea.height`.
const double sheetHandleAreaHeight = 24;

/// 핸들 자리의 끌기 터치 높이(px). `frame.json` `sheet.parts.handleArea.minTarget`.
const double sheetHandleTouchHeight = 44;

/// 끌어내려 닫는 기준: 시트 높이의 이 비율 이상.
const double _dismissFraction = 0.25;

/// 마지막 이동 뒤 이 시간이 지나 놓으면 멈춘 것으로 보아 속도를 0으로 칩니다.
///
/// 실기기에서는 보조 판정입니다. 실제로는 `VelocityTracker`가 마지막 표본 뒤 40ms가
/// 지나면 속도를 0으로 내는 판정(샘플링 시계의 Stopwatch)이 먼저 작동합니다. 이 값은
/// 이벤트 시각(프레임 시각)만으로도 멈춤을 판정하는 하한입니다.
const Duration _staleSample = Duration(milliseconds: 80);

/// 끌어내려 닫는 기준 속도(px/s).
const double _dismissVelocity = 700;

/// 끌어내리다 놓은 시트를 닫을지: 손가락이 시트 높이의 25% 이상 내려왔거나(`frame.json`
/// `sheet.parts.dragDismiss.threshold`) 아래 방향 속도가 700px/s를 넘으면 닫습니다(A120).
@visibleForTesting
bool sheetShouldDismiss({
  required double distance,
  required double velocity,
  required double sheetHeight,
}) => distance >= sheetHeight * _dismissFraction || velocity > _dismissVelocity;

/// [size]의 시트가 가질 수 있는 최대 높이.
double sheetMaxHeight(BuildContext context, SheetSize size) {
  final screen = MediaQuery.sizeOf(context).height;
  return switch (size) {
    SheetSize.half => screen * sheetHalfFraction,
    SheetSize.full =>
      screen - MediaQuery.viewPaddingOf(context).top - sheetFullTopGap,
  };
}

/// 시트 틀: 위 모서리 `radius.xl`, `bg.sheet`, 높이 24 핸들 자리(끌기 터치 44), 좌우와 아래
/// 안쪽 `space.24`.
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
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: sheetHandleAreaHeight,
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
                    // 시트는 셸 바깥 navigator에 쌓여 셸의 Material을 벗어나므로, 내용 글자가
                    // MaterialApp의 오류 스타일(노란 이중 밑줄)을 받지 않게 그리지 않는
                    // Material 조상을 둡니다(탭 셸과 같은 방식).
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          Space.s24,
                          0,
                          Space.s24,
                          Space.s24 + MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
                // 핸들 자리의 끌기 터치 44. 본문이 스크롤된 상태여도 여기서 끌면 시트가
                // 내려갑니다. 누르기는 통과시켜 아래 내용이 받습니다(translucent).
                Positioned(
                  key: const ValueKey('sheet.handleArea'),
                  top: 0,
                  left: 0,
                  right: 0,
                  height: sheetHandleTouchHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: onDragUpdate,
                    onVerticalDragEnd: onDragEnd,
                    onVerticalDragCancel: onDragCancel,
                  ),
                ),
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
/// 시트 안에서 다시 열면 `sheet.stack`으로 위에 쌓입니다. 아래 시트는 둥근 윗변과 핸들이 위
/// 시트 위로 14px 보이게 올라가고 조금 어두워지며, 뒤 앱 화면은 그대로입니다(V110).
/// 뒤로 가기, 끌어내리기, 바깥 누르기는 모두 맨 위 시트 하나만 닫습니다(V100).
Future<T?> showMyungliSheet<T>(
  BuildContext context, {
  required SheetSize size,
  required WidgetBuilder builder,
  String? semanticLabel,
}) {
  // 시트 안에서 여는 시트는 아래 시트의 덮개를 그대로 쓰고 자기 덮개는 더하지 않습니다.
  final below = ModalRoute.of(context);
  return overlayNavigatorOf(context).push<T>(
    _SheetRoute<T>(
      size: size,
      builder: builder,
      semanticLabel: semanticLabel,
      below: below is _SheetRoute ? below : null,
    ),
  );
}

/// 위 시트가 쌓인 동안 아래 시트가 지닐 수 있는 최대 높이. [size]의 최대 높이에서, 아래 시트
/// 머리 14px(`sheet.stack.peek`)가 full 시트 윗변(위 안전 영역 + 12) 아래에 남도록 줄입니다.
///
/// 위 시트 높이는 열기 전에 정하고 열리는 동안 바뀌지 않습니다. 줄어든 높이에 다 들어가지
/// 않는 내용은 시트 안에서 세로로 스크롤합니다(V109).
double sheetStackedMaxHeight(BuildContext context, SheetSize size) => math.min(
  sheetMaxHeight(context, size),
  sheetMaxHeight(context, SheetSize.full) - PatternValues.stackPeekHeight,
);

/// 아래 시트가 다 쌓였을 때 올라갈 거리(`sheet.stack.peek.rule`).
///
/// 아래 시트 윗변이 위 시트 윗변보다 14px 위에 오게 올립니다. 두 시트는 모두 화면 아래에
/// 붙으므로 거리는 두 높이로 정해지고, 아래 시트가 이미 더 크면(머리가 이미 보이면) 0입니다.
@visibleForTesting
double sheetStackLift({required double below, required double above}) =>
    math.max(0, above + PatternValues.stackPeekHeight - below);

/// 시트·확인 창처럼 화면 위에 덮는 route를 쌓을 navigator. 화면 셸([SheetScreenBelow]) 범위
/// 밖에서 가장 가까운 것입니다.
///
/// 셸 안쪽 navigator(탭 화면의 branch)에 쌓으면 덮는 route가 탭 바 아래에 깔려 덮개가 탭 바를
/// 덮지 못합니다. 그렇다고 root navigator를 고르면 앱 안의 앱(Widgetbook의 미리보기
/// MaterialApp)에서 바깥 navigator에 쌓여 테마를 잃습니다.
/// 범위 안이 아니면 가장 가까운 navigator 그대로입니다.
NavigatorState overlayNavigatorOf(BuildContext context) {
  var navigator = Navigator.of(context);
  while (navigator.context.getInheritedWidgetOfExactType<_ScreenShellScope>() !=
      null) {
    // Navigator.of(navigator.context)는 자기 자신을 돌려주므로 조상을 직접 찾습니다.
    final outer = navigator.context.findAncestorStateOfType<NavigatorState>();
    if (outer == null) break;
    navigator = outer;
  }
  return navigator;
}

/// [SheetScreenBelow] 안쪽임을 알리는 표지.
class _ScreenShellScope extends InheritedWidget {
  const new({required super.child});

  @override
  bool updateShouldNotify(_ScreenShellScope oldWidget) => false;
}

/// 화면 셸의 범위 표지. 이 안쪽에서 연 시트와 확인 창은 셸 바깥 navigator에 쌓입니다
/// ([overlayNavigatorOf]).
///
/// 탭 화면의 갈래 navigator에 쌓으면 시트가 탭 바 아래에 깔리므로 셸 바깥에 쌓습니다. 시트가
/// 겹쳐도 뒤 앱 화면은 크기와 밝기가 그대로라(`sheet.stack.screenBelow`, V110) 화면 자체에는
/// 아무것도 입히지 않습니다.
class SheetScreenBelow extends StatelessWidget {
  /// 화면 내용을 감쌉니다.
  const new({required this.child, super.key});

  /// 화면 내용.
  final Widget child;

  @override
  Widget build(BuildContext context) => _ScreenShellScope(child: child);
}

/// 시트 안 첫 제목. 시트가 열리면 스크린리더 초점이 여기로 옵니다(`focusOnOpen: first-heading`).
///
/// 위에 `space.8`을 둡니다(`frame.json` `sheet.parts.title.marginTop`, 핸들 자리 아래).
///
/// 시트 안에서 이 위젯을 여러 개 쓰면 먼저 만들어진 하나만 초점을 받습니다. 쓰지 않으면
/// 시트 이름([showMyungliSheet]의 `semanticLabel`)만 알려지고 초점은 플랫폼 기본을 따릅니다.
class SheetHeading extends StatefulWidget {
  /// 제목을 header 의미로 감쌉니다.
  const new({required this.child, super.key});

  /// 제목 위 여백(핸들 자리 아래 `space.8`). 제목과 같은 줄에 놓는 위젯이 세로 자리를 맞출 때
  /// 이 값을 씁니다.
  static const double topGap = Space.s8;

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: SheetHeading.topGap),
    child: Semantics(header: true, child: widget.child),
  );
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

/// 위에 쌓인 시트가 아래 시트에 알리는 값: 위 시트 높이와 끌어 내린 비율(0~1).
typedef _AboveSheet = ({double height, double release});

const _AboveSheet _noSheetAbove = (height: 0, release: 0);

class _SheetRoute<T> extends PopupRoute<T> {
  new({
    required this.size,
    required this.builder,
    required this.below,
    this.semanticLabel,
  });

  final SheetSize size;
  final WidgetBuilder builder;
  final String? semanticLabel;

  /// 이 시트 바로 아래의 시트. 없으면 첫 시트입니다.
  final _SheetRoute<dynamic>? below;

  /// 이 시트 위에 쌓인 시트의 높이와 끌기 비율. 아래 시트 머리(`peek`) 계산에 씁니다.
  final ValueNotifier<_AboveSheet> above = ValueNotifier(_noSheetAbove);

  bool _disposed = false;

  /// 시트 안에서 연 시트인지. 아래 시트의 덮개를 그대로 씁니다.
  bool get underSheet => below != null;

  /// 위 시트가 높이나 끌기 비율을 알립니다. 이미 닫힌 시트면 무시합니다.
  void reportAbove(_AboveSheet value) {
    if (!_disposed) above.value = value;
  }

  @override
  void dispose() {
    below?.reportAbove(_noSheetAbove);
    _disposed = true;
    above.dispose();
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

  /// 손가락을 따라 시트가 내려간 거리. 바뀌면 아래 시트에 끌기 비율을 알립니다(`peek.drag`).
  double get _drag => _dragValue;
  set _drag(double value) {
    _dragValue = value;
    _reportToBelow();
  }

  double _dragValue = 0;
  double _dragFrom = 0;

  /// 이 시트 틀의 높이. 첫 레이아웃 뒤에 알게 됩니다.
  double _frameHeight = 0;

  /// iOS 같은 Bouncing 본문이 맨 위에서 밀려난 양. 시트가 그만큼 따라 내려가므로 본문은
  /// 같은 양만큼 되올려 이중으로 움직여 보이지 않게 합니다.
  double _bounce = 0;

  /// 본문 스크롤로 끄는 동안 손가락이 아래로 움직인 누적 거리. 닫기 판정은 이 값으로 합니다
  /// (A120). iOS bounce 본문은 마찰 때문에 [_drag]가 손가락보다 덜 움직여 시트 높이의 25%에
  /// 잘 닿지 않으므로 따로 셉니다.
  double _fingerTravel = 0;
  bool _scrollDragging = false;
  bool _dismissing = false;
  VelocityTracker _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
  Duration? _lastSample;
  final GlobalKey _frameKey = GlobalKey();
  final _HeadingClaim _headingClaim = _HeadingClaim();

  double get _snapCurve => Curves.easeOut.transform(_snap.value);

  /// 아래 시트에 이 시트 높이와 끌어 내린 비율을 알립니다.
  void _reportToBelow() {
    final below = widget.route.below;
    if (below == null || _frameHeight <= 0) return;
    below.reportAbove((
      height: _frameHeight,
      release: (_dragValue / _frameHeight).clamp(0, 1).toDouble(),
    ));
  }

  void _onFrameSize(Size size) {
    if (!mounted || size.height == _frameHeight) return;
    setState(() => _frameHeight = size.height);
    _reportToBelow();
  }

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
    _fingerTravel = 0;
  }

  /// 본문 바깥(시트 프레임)에서 받은 드래그: 스크롤할 수 없는 본문.
  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    _snap.stop();
    _track(details);
    setState(() => _drag = math.max(0, _drag + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) =>
      _finishDrag(details.velocity.pixelsPerSecond.dy, distance: _drag);

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
        _fingerTravel += -overscroll;
        setState(() => _drag += -overscroll);
      case ScrollUpdateNotification()
          when metrics.pixels < metrics.minScrollExtent:
        final amount = metrics.minScrollExtent - metrics.pixels;
        if (n.dragDetails case final dragDetails?) {
          _snap.stop();
          _scrollDragging = true;
          _track(dragDetails);
          // 경계를 막 넘는 갱신이면 손가락 이동 중 본문을 맨 위까지 스크롤한 몫은 빼고,
          // 경계 아래로 넘어간 몫만 셉니다.
          final previous = metrics.pixels - (n.scrollDelta ?? 0);
          final scrolled = math.max(0, previous - metrics.minScrollExtent);
          _fingerTravel = math.max(
            0,
            _fingerTravel + dragDetails.delta.dy - scrolled,
          );
        } else if (_scrollDragging) {
          // 손을 뗀 순간: 이후의 되돌아옴은 본문 bounce가 끌고 가고 시트가 따라갑니다.
          final dismiss = _shouldDismiss(_fingerTravel, _releaseVelocity());
          _resetTracking();
          if (dismiss) {
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
        _fingerTravel = 0;
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
        _fingerTravel = math.max(0, _fingerTravel - absorbed);
        setState(() => _drag -= absorbed);
      case ScrollEndNotification() when _scrollDragging && _drag > 0:
        final velocity =
            n.dragDetails?.velocity.pixelsPerSecond.dy ?? _releaseVelocity();
        _finishDrag(velocity, distance: _fingerTravel);
      default:
        break;
    }
    return false;
  }

  bool _shouldDismiss(double distance, double velocity) => sheetShouldDismiss(
    distance: distance,
    velocity: velocity,
    sheetHeight: _frameKey.currentContext?.size?.height ?? 0,
  );

  /// 놓은 순간 닫을지 정합니다. [distance]는 손가락이 아래로 움직인 거리입니다.
  void _finishDrag(double velocity, {required double distance}) {
    _resetTracking();
    if (_shouldDismiss(distance, velocity)) {
      unawaited(_dismiss());
      return;
    }
    _settleBack();
  }

  /// 이 시트를 닫습니다. `PopScope`가 막아 닫히지 않으면 제자리로 돌아옵니다.
  Future<void> _dismiss() async {
    _dismissing = true;
    final navigator = Navigator.of(context);
    if (!widget.route.isCurrent) {
      // 손을 뗀 뒤 닫기 판정 전에 위에 다른 route(예 용어 설명 시트)가 열렸습니다.
      // `maybePop`은 맨 위를 닫으므로 이 시트만 뺍니다. `removeRoute`는 `PopScope`를
      // 거치지 않으므로, 이 시트가 닫기를 막으면 빼지 않고 제자리로 돌아옵니다.
      if (widget.route.popDisposition == RoutePopDisposition.doNotPop) {
        _dismissing = false;
        if (_bounce == 0) _settleBack();
        return;
      }
      navigator.removeRoute(widget.route);
      return;
    }
    // `maybePop`은 `PopScope`가 막아도 true를 주므로, route가 실제로 빠졌는지 봅니다.
    await navigator.maybePop();
    if (!mounted || !widget.route.isActive) return;
    _dismissing = false;
    // 본문이 bounce로 되돌아오는 중이면 그 값이 시트를 끌고 가므로 따로 움직이지 않습니다.
    if (_bounce == 0) _settleBack();
  }

  /// 바깥 누르기: 맨 위 시트인 이 시트 하나만 닫습니다(V100). 입력이 있는 시트의 확인
  /// (`PopScope`)도 끌어 닫기와 같이 거칩니다.
  void _onTapOutside() => unawaited(_dismiss());

  @override
  Widget build(BuildContext context) {
    final prefs = MotionPrefs.of(context);
    final route = widget.route;
    final maxHeight = route.underSheet
        ? sheetStackedMaxHeight(context, route.size)
        : sheetMaxHeight(context, route.size);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final exiting = widget.animation.status == AnimationStatus.reverse;
        final pattern = exiting
            ? InteractionPattern.sheetExit
            : InteractionPattern.sheetEnter;
        final t = exiting ? _exit : widget.animation;
        final frame = _SizeReporter(
          onSize: _onFrameSize,
          child: MyungliSheetFrame(
            key: _frameKey,
            maxHeight: maxHeight,
            semanticLabel: route.semanticLabel,
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
                  child: Builder(builder: route.builder),
                ),
              ),
            ),
          ),
        );
        final sheet = _StackedBelow(
          above: route.above,
          secondaryAnimation: widget.secondaryAnimation,
          frameHeight: _frameHeight,
          prefs: prefs,
          child: frame,
        );
        // 바깥은 맨 위 시트 밖 전부입니다(덮개와 아래 시트의 보이는 머리). 시트 안에서 연
        // 시트는 아래 시트의 덮개를 그대로 쓰고 누르기만 이 층에서 받습니다. 위에 시트가
        // 쌓이면 이 시트의 닫기 동작은 스크린리더에서 숨겨 맨 위 시트의 것 하나만 남깁니다.
        final outside = _HiddenWhileCovered(
          secondaryAnimation: widget.secondaryAnimation,
          child: Semantics(
            button: true,
            label: l10n.sheetDismiss,
            onTap: _onTapOutside,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTapOutside,
                child: route.underSheet
                    ? const SizedBox.expand()
                    : KeyedSubtree(
                        key: const ValueKey('sheet.scrim'),
                        child: animateScrim(pattern, t: t, prefs: prefs),
                      ),
              ),
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(child: outside),
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

/// 위에 시트가 쌓인 동안의 아래 시트(`sheet.stack` `sheetBelow`, V110).
///
/// 위 시트 높이를 안 뒤 올라갈 거리([sheetStackLift])를 정하고, 위 시트를 끌어 내리는 동안은
/// 그 비율만큼 제자리 쪽으로 내려옵니다. 위 시트가 열린 동안 아래 시트(보이는 머리 포함)는
/// 스크린리더에서 숨깁니다(`peek.a11y`, [_HiddenWhileCovered]).
class _StackedBelow extends StatelessWidget {
  const new({
    required this.above,
    required this.secondaryAnimation,
    required this.frameHeight,
    required this.prefs,
    required this.child,
  });

  final ValueListenable<_AboveSheet> above;
  final Animation<double> secondaryAnimation;
  final double frameHeight;
  final MotionPrefs prefs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([above, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final value = above.value;
        return _HiddenWhileCovered(
          secondaryAnimation: secondaryAnimation,
          child: animate(
            InteractionPattern.sheetStack,
            t: secondaryAnimation,
            prefs: prefs,
            options: PatternOptions(
              stackLift: value.height > 0
                  ? sheetStackLift(below: frameHeight, above: value.height)
                  : 0,
              stackRelease: value.release,
            ),
            child: child!,
          ),
        );
      },
    );
  }
}

/// 위에 시트가 쌓여 있는 동안(열리고 닫히는 중 포함) [child]를 스크린리더에서 숨깁니다.
class _HiddenWhileCovered extends StatelessWidget {
  const new({required this.secondaryAnimation, required this.child});

  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: secondaryAnimation,
    child: child,
    builder: (context, child) => ExcludeSemantics(
      excluding: secondaryAnimation.status != AnimationStatus.dismissed,
      child: child,
    ),
  );
}

/// 레이아웃이 끝나면 자기 크기를 [onSize]로 알립니다(크기가 바뀐 때만, 프레임 뒤에).
class _SizeReporter extends SingleChildRenderObjectWidget {
  const new({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  new(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    final reported = _reported = size;
    // 레이아웃 중에는 상태를 바꿀 수 없으므로 프레임 뒤에 알립니다.
    SchedulerBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}

/// iOS bounce로 본문이 [bounce]만큼 밀려난 것을 되올립니다.
///
/// 그리는 위치만 옮기고 본문 크기(viewport 높이)는 바꾸지 않습니다. 크기를 bounce만큼 늘리면
/// viewport와 `maxScrollExtent`가 프레임마다 바뀌어 스크롤 위치가 되돌려지고, 천천히 끌 때
/// 시트가 제자리에서 떨리며 닫히지 않았습니다(F-027, A120). 끄는 동안 본문 아래에
/// [bounce]만큼 시트 바탕이 더 보입니다.
class _BounceCompensation extends StatelessWidget {
  const new({required this.bounce, required this.child});

  final double bounce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 구조는 항상 같게 둡니다(본문의 스크롤 상태가 유지되도록).
    return Transform.translate(offset: Offset(0, -bounce), child: child);
  }
}
