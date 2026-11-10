import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// `unlock.glint`(열림 반짝임, D118 ②, V112)의 박자 하나. 한 시트(또는 한 문장) 안 대상
/// [UnlockGlint]가 이 박자 하나를 함께 씁니다(`together`).
///
/// 박자:
/// * 처음: 지나갈 수 있게 되면(아래 멈춤 조건이 모두 풀리면) [firstDelay] 뒤 한 번. 열린
///   내용이 `appear.seep`으로 나타나는 시트는 그 시간을 주고, 처음부터 열려 있던 시트는 0이라
///   시트가 다 올라온 직후입니다.
/// * 그 뒤: 앞 반짝임 시작에서 [PatternValues.glintInterval]마다 `breathe`(1800ms) 동안 한 번.
///
/// 멈춤(`pauseWhen`): 앱이 배경으로 감, 이 화면 route가 아직 들어오는 중이거나 위 route에
/// 덮임(`sheet.stack` 아래 층, route의 `secondaryAnimation`), `TickerMode`가 꺼짐, 대상이
/// 모두 스크롤 영역 밖. 멈추면 지나가던 띠를 지우고, 다시 지나갈 수 있게 되면 다음 15초 박자에
/// 지나갑니다(아직 한 번도 지나가지 않았으면 [firstDelay]). 이 위젯이 빠지면(시트 닫힘) 끝납니다.
///
/// 동작 줄이기면(`reduceMotion: replace`) 박자를 돌리지 않고, 대상은 띠를 그리지 않습니다.
/// 그 자리의 `unlock.mark`는 부르는 쪽이 [UnlockGlintScope.replacedOf]를 보고 그립니다.
class UnlockGlintScope extends StatefulWidget {
  /// [child] 안 [UnlockGlint]의 박자를 만듭니다.
  const new({required this.child, this.firstDelay = Duration.zero, super.key});

  /// 첫 반짝임까지 기다리는 시간(열린 내용이 나타나는 시간).
  final Duration firstDelay;

  /// 대상을 담은 내용.
  final Widget child;

  /// 위 박자가 동작 줄이기로 `unlock.mark`를 대신 그려야 하는지. 박자가 없으면 false입니다.
  static bool replacedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlintScope>()?.replaced ??
      false;

  @override
  State<UnlockGlintScope> createState() => _UnlockGlintScopeState();
}

class _UnlockGlintScopeState extends State<UnlockGlintScope>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: InteractionPattern.unlockGlint.duration,
  );

  /// 다음 반짝임.
  Timer? _next;

  /// 한 번이라도 지나갔는지. 다시 이어질 때 첫 기다림 대신 15초 박자를 씁니다.
  bool _glinted = false;

  /// 지금 박자가 돌고 있는지.
  bool _running = false;

  bool _replaced = false;
  bool _tickerEnabled = true;
  bool _appActive = true;
  ModalRoute<Object?>? _route;

  /// 스크롤 영역 안에 보이는 대상.
  final Set<Object> _visible = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _replaced =
        MotionPrefs.of(context).reduceMotion &&
        InteractionPattern.unlockGlint.reduceMotion == ReduceMotionRule.replace;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _route?.animation?.removeStatusListener(_onRouteStatus);
      _route?.secondaryAnimation?.removeStatusListener(_onRouteStatus);
      _route = route;
      route?.animation?.addStatusListener(_onRouteStatus);
      route?.secondaryAnimation?.addStatusListener(_onRouteStatus);
    }
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _update();
  }

  void _onRouteStatus(AnimationStatus _) => _update();

  /// 대상 [target]이 스크롤 영역 안에 보이는지 알립니다.
  void _report(Object target, {required bool visible}) {
    final changed = visible ? _visible.add(target) : _visible.remove(target);
    if (changed) _update();
  }

  /// route가 다 들어왔고 위에 덮인 route가 없는지.
  bool get _routeSettled {
    final route = _route;
    if (route == null) return true;
    final entered =
        route.animation == null ||
        route.animation!.status == AnimationStatus.completed;
    final covered =
        route.secondaryAnimation != null &&
        route.secondaryAnimation!.status != AnimationStatus.dismissed;
    return entered && !covered;
  }

  /// 멈춤 조건을 다시 보고 박자를 켜거나 끕니다.
  void _update() {
    if (!mounted) return;
    final shouldRun =
        !_replaced &&
        _appActive &&
        _tickerEnabled &&
        _routeSettled &&
        _visible.isNotEmpty;
    if (shouldRun == _running) return;
    _running = shouldRun;
    _next?.cancel();
    _next = null;
    if (shouldRun) {
      _next = Timer(
        _glinted ? PatternValues.glintInterval : widget.firstDelay,
        _beat,
      );
    } else {
      // 지나가던 띠는 지웁니다. 다시 이어지면 처음부터 지나갑니다.
      _sweep
        ..stop()
        ..value = 0;
    }
  }

  /// 띠를 한 번 보내고 다음 박자를 잡습니다.
  void _beat() {
    if (!mounted || !_running) return;
    _glinted = true;
    _sweep.forward(from: 0);
    _next = Timer(PatternValues.glintInterval, _beat);
  }

  @override
  void dispose() {
    _next?.cancel();
    _route?.animation?.removeStatusListener(_onRouteStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteStatus);
    WidgetsBinding.instance.removeObserver(this);
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _GlintScope(owner: this, replaced: _replaced, child: widget.child);
}

class _GlintScope extends InheritedWidget {
  const new({
    required this.owner,
    required this.replaced,
    required super.child,
  });

  final _UnlockGlintScopeState owner;
  final bool replaced;

  @override
  bool updateShouldNotify(_GlintScope oldWidget) =>
      owner != oldWidget.owner || replaced != oldWidget.replaced;
}

/// `unlock.glint` 대상 글자. 위 [UnlockGlintScope]의 박자에 맞춰 [child] 글자 모양 안으로
/// `gradient.unlocked` 띠가 지나갑니다(`text-fill`, 글자 기본색은 그대로).
///
/// 띠는 [child] 상자 전체를 한 번에 비스듬히(100°) 지나가고(여러 줄 문단도 한 띠), 너비는 상자
/// 너비의 30%, 양 끝은 글자 기본색으로 부드럽게 이어집니다. 지나가지 않는 동안에는 층을 만들지
/// 않습니다. 위 박자가 없거나 동작 줄이기면 [child]를 그대로 둡니다. 스크린리더는 읽지 않고
/// 배치와 누름도 그대로입니다.
class UnlockGlint extends StatefulWidget {
  /// [child] 글자에 반짝임을 입힙니다.
  const new({required this.child, super.key});

  /// 대상 글자.
  final Widget child;

  @override
  State<UnlockGlint> createState() => _UnlockGlintState();
}

class _UnlockGlintState extends State<UnlockGlint> {
  _UnlockGlintScopeState? _owner;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context
        .dependOnInheritedWidgetOfExactType<_GlintScope>()
        ?.owner;
    if (!identical(owner, _owner)) {
      _owner?._report(this, visible: false);
      _owner = owner;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_checkVisible);
      _position = position;
      position?.addListener(_checkVisible);
    }
  }

  /// 대상이 가장 가까운 스크롤 영역과 겹치는지 박자에 알립니다(겹치는 글자가 없으면 화면 밖).
  void _checkVisible() {
    final owner = _owner;
    if (!mounted || owner == null) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    final visible =
        viewport is! RenderBox ||
        !viewport.hasSize ||
        _globalRect(box).overlaps(_globalRect(viewport));
    owner._report(this, visible: visible);
  }

  static Rect _globalRect(RenderBox box) =>
      box.localToGlobal(Offset.zero) & box.size;

  @override
  void dispose() {
    _position?.removeListener(_checkVisible);
    _owner?._report(this, visible: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = _owner;
    if (owner == null || owner._replaced) {
      return widget.child;
    }
    // 배치가 바뀔 수 있으므로 그린 뒤마다 보이는지 다시 봅니다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
    return _GlintMask(
      sweep: owner._sweep,
      colors: context.tokens.gradients.unlocked.colors,
      stops: context.tokens.gradients.unlocked.stops,
      child: widget.child,
    );
  }
}

/// [sweep]이 앞으로 가는 동안에만 [child]를 띠 shader로 칠합니다(`BlendMode.srcATop`).
class _GlintMask extends SingleChildRenderObjectWidget {
  const new({
    required this.sweep,
    required this.colors,
    required this.stops,
    super.child,
  });

  final Animation<double> sweep;
  final List<Color> colors;
  final List<double>? stops;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderUnlockGlint(sweep: sweep, colors: colors, stops: stops);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderUnlockGlint renderObject,
  ) {
    renderObject
      ..sweep = sweep
      ..colors = colors
      ..stops = stops;
  }
}

/// `unlock.glint` 띠를 그리는 render object. 테스트가 띠가 지나가는 중인지 봅니다.
class RenderUnlockGlint extends RenderProxyBox {
  /// [sweep] 진행에 맞춰 [colors] 띠를 그립니다.
  new({required this._sweep, required this._colors, required this._stops});

  Animation<double> _sweep;
  List<Color> _colors;
  List<double>? _stops;

  /// 띠 진행(0→1 선형, 곡선은 여기서 입힘).
  Animation<double> get sweep => _sweep;
  set sweep(Animation<double> value) {
    if (identical(value, _sweep)) return;
    if (attached) _sweep.removeListener(_onTick);
    _sweep = value;
    if (attached) _sweep.addListener(_onTick);
    _onTick();
  }

  /// 띠 멈춤 색(`gradient.unlocked`).
  List<Color> get colors => _colors;
  set colors(List<Color> value) {
    if (value == _colors) return;
    _colors = value;
    markNeedsPaint();
  }

  /// 띠 멈춤 위치(`gradient.unlocked`). null이면 고르게 나눕니다.
  List<double>? get stops => _stops;
  set stops(List<double>? value) {
    if (value == _stops) return;
    _stops = value;
    markNeedsPaint();
  }

  /// 띠가 지나가는 중인지.
  bool get glinting =>
      _sweep.status == AnimationStatus.forward &&
      _sweep.value > 0 &&
      _sweep.value < 1;

  bool _wasGlinting = false;

  void _onTick() {
    final now = glinting;
    if (now != _wasGlinting) {
      _wasGlinting = now;
      markNeedsCompositingBitsUpdate();
    }
    if (now || layer != null) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sweep.addListener(_onTick);
    _wasGlinting = glinting;
  }

  @override
  void detach() {
    _sweep.removeListener(_onTick);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && glinting;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || !glinting) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final progress = InteractionPattern.unlockGlint.curve.transform(
      _sweep.value,
    );
    final mask = ((layer as ShaderMaskLayer?) ?? ShaderMaskLayer())
      ..shader = unlockGlintShader(size, progress, _colors, _stops)
      ..maskRect = offset & size
      ..blendMode = BlendMode.srcATop;
    layer = mask;
    context.pushLayer(mask, super.paint, offset);
  }
}

/// [size] 상자를 진행 [progress](곡선 입힌 0~1)만큼 지난 띠의 자리.
///
/// 띠는 [PatternValues.glintBandAngle] 방향(`direction`, 단위 벡터)으로 재고, 상자 네 모서리를
/// 그 방향에 투영한 범위가 `boxStart`~`boxEnd`입니다. 띠 너비는 상자 너비의
/// [PatternValues.glintBandWidth]이고, 진행 0에서는 띠 끝(`bandEnd`)이 `boxStart`에, 1에서는
/// 띠 시작(`bandStart`)이 `boxEnd`에 닿아 여러 줄 문단도 한 띠가 상자 밖에서 밖으로 지나갑니다.
@visibleForTesting
({
  Offset direction,
  double boxStart,
  double boxEnd,
  double bandStart,
  double bandEnd,
})
unlockGlintBand(Size size, double progress) {
  const radians = PatternValues.glintBandAngle * math.pi / 180;
  // CSS 각도: 0°가 위쪽, 시계 방향.
  final direction = Offset(math.sin(radians), -math.cos(radians));
  double along(Offset point) =>
      point.dx * direction.dx + point.dy * direction.dy;
  final corners = [
    along(Offset.zero),
    along(Offset(size.width, 0)),
    along(Offset(0, size.height)),
    along(Offset(size.width, size.height)),
  ];
  final boxStart = corners.reduce(math.min);
  final boxEnd = corners.reduce(math.max);
  final band = size.width * PatternValues.glintBandWidth;
  final bandStart = boxStart - band + (boxEnd - boxStart + band) * progress;
  return (
    direction: direction,
    boxStart: boxStart,
    boxEnd: boxEnd,
    bandStart: bandStart,
    bandEnd: bandStart + band,
  );
}

/// [size] 상자를 진행 [progress]만큼 지난 띠 shader(상자 왼쪽 위가 원점, [unlockGlintBand]).
///
/// 띠 안은 [colors]를 가운데 60%에 펴고 양 끝 20%는 투명으로 이어, 띠 밖과 띠 가장자리는
/// 글자 기본색이 그대로 보입니다(`srcATop`).
ui.Shader unlockGlintShader(
  Size size,
  double progress,
  List<Color> colors,
  List<double>? stops,
) {
  final band = unlockGlintBand(size, progress);
  final colorStops =
      stops ??
      [
        if (colors.length == 1)
          0.5
        else
          for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
      ];
  return ui.Gradient.linear(
    band.direction * band.bandStart,
    band.direction * band.bandEnd,
    [
      colors.first.withValues(alpha: 0),
      ...colors,
      colors.last.withValues(alpha: 0),
    ],
    [0, for (final stop in colorStops) _edge + stop * (1 - _edge * 2), 1],
  );
}

/// 띠 양 끝에서 투명에서 띠 색으로 이어지는 몫.
const double _edge = 0.2;
