import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 최소 터치 크기(px). 명세 `term-token`·`depth-link`·`reaction-button` 모두 44입니다.
const double sentenceMinTarget = 44;

/// 넓힘 없이 판정하는 [HitSlopPassage] 첫 판정의 깊이. 0보다 크면 [VerticalHitSlop]이 넓히지
/// 않습니다. 눌림 판정은 한 번에 동기로 끝나므로 판정 동안만 바뀝니다.
int _exactPassDepth = 0;

/// [size] 상자의 [child]를 [position]에서 판정합니다. 넓힌 부분의 눌림은 자식 판정이 자기 영역
/// 안에서만 성립하므로 가장자리로 모아 넘깁니다. [VerticalHitSlop]과 [HitSlopPassage]가 함께
/// 씁니다.
bool _hitTestClamped(
  BoxHitTestResult result,
  RenderBox? child,
  Size size,
  Offset position,
) {
  final clamped = Offset(
    position.dx.clamp(0, size.width - 0.01),
    position.dy.clamp(0, size.height - 0.01),
  );
  return result.addWithRawTransform(
    transform: null,
    position: position,
    hitTest: (result, _) => child?.hitTest(result, position: clamped) ?? false,
  );
}

/// 자식이 [minHeight]보다 낮으면 위아래로 눌리는 영역만 넓힙니다. 모양과 배치는 그대로입니다.
///
/// 문장 속 글자는 줄 높이(24~28px)가 44px보다 낮아 터치 영역이 모자랍니다. 명세는
/// "줄 높이까지 위아래로 넓힘"이라, 레이아웃을 바꾸지 않고 눌림 판정만 넓힙니다.
/// 넓힌 영역은 위아래 이웃 줄의 글자 위까지 겹칠 수 있고, 겹친 곳은 이 글자가 받습니다
/// (두 줄에 걸친 가까운 용어끼리는 먼저 판정되는 쪽이 받음). 문단 맨 위·맨 아래 줄은
/// 문단 영역 밖이라 넓혀도 닿지 않는 한계가 있습니다(인라인 글자의 한계).
class VerticalHitSlop extends SingleChildRenderObjectWidget {
  /// 눌림 영역을 넓힙니다.
  const new({
    required super.child,
    this.minHeight = sentenceMinTarget,
    this.minWidth = 0,
    this.widenLeftOnly = false,
    super.key,
  });

  /// 눌림 영역의 최소 높이.
  final double minHeight;

  /// 눌림 영역의 최소 폭. 자식이 더 좁으면 좌우로 넓힙니다(0이면 넓히지 않음).
  final double minWidth;

  /// true면 폭은 물리적 왼쪽으로만 넓힙니다(오른쪽 끝선 바깥은 부모 경계라 눌림이 닿지 않음. 방향 전환 없음).
  final bool widenLeftOnly;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVerticalHitSlop(
        minHeight: minHeight,
        minWidth: minWidth,
        widenLeftOnly: widenLeftOnly,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderVerticalHitSlop)
        ..minHeight = minHeight
        ..minWidth = minWidth
        ..widenLeftOnly = widenLeftOnly;
}

class _RenderVerticalHitSlop extends RenderProxyBox {
  new({
    required this._minHeight,
    required this._minWidth,
    required this._widenLeftOnly,
  });

  double _minHeight;
  double _minWidth;
  bool _widenLeftOnly;

  // 눌림 판정에서만 읽는 값이라 getter가 필요 없습니다.
  // ignore: avoid_setters_without_getters
  set minHeight(double value) => _minHeight = value;

  // 눌림 판정에서만 읽는 값이라 getter가 필요 없습니다.
  // ignore: avoid_setters_without_getters
  set minWidth(double value) => _minWidth = value;

  // 눌림 판정에서만 읽는 값이라 getter가 필요 없습니다.
  // ignore: avoid_setters_without_getters
  set widenLeftOnly(bool value) => _widenLeftOnly = value;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 바깥 [HitSlopPassage]가 넓힘 없이 먼저 판정하는 동안은 자기 영역만 봅니다.
    final widen = _exactPassDepth == 0;
    final slop = widen ? math.max(0, (_minHeight - size.height) / 2) : 0;
    final extra = widen ? math.max(0, _minWidth - size.width) : 0;
    final slopStart = _widenLeftOnly ? extra : extra / 2;
    final slopEnd = _widenLeftOnly ? 0 : extra / 2;
    final inside =
        position.dx >= -slopStart &&
        position.dx < size.width + slopEnd &&
        position.dy >= -slop &&
        position.dy < size.height + slop;
    if (!inside) return false;
    return _hitTestClamped(result, child, size, position);
  }
}

/// 자식 안의 [VerticalHitSlop]이 넓힌 눌림이 이 상자 경계에서 막히지 않게, 위 [top]과 아래
/// [bottom]만큼 바깥의 눌림을 받아 자식 가장자리로 모아 넘깁니다. 모양과 배치는 그대로입니다.
///
/// 보통 상자는 자기 영역 밖의 눌림을 자식에게 넘기지 않습니다. 넓힐 자리가 부모 영역 끝에 붙은
/// 글줄(예: 날짜 머리 맨 아래 줄의 덕일 알약)이면 그 부모를 이것으로 감쌉니다. 자식 영역 안의
/// 눌림은 그대로 넘기고, 넓힌 부분은 세로만 가장자리로 모으므로(가로 위치 그대로) 그 위치의
/// 자식이 받습니다. 받는 자식이 없으면 이 상자도 받지 않습니다.
///
/// 판정은 두 번입니다. 먼저 안쪽 [VerticalHitSlop]을 넓히지 않고 판정해 그 위치를 실제로 덮은
/// 자식이 받고, 아무도 덮지 않았을 때만 넓혀 다시 판정합니다. 그래서 줄 넘김으로 위아래에 쌓인
/// 알약끼리 아래 알약의 넓힘이 윗 알약을 가로채지 않습니다(옆 칸과 겹치는 쪽은 넓히지 않음).
class HitSlopPassage extends SingleChildRenderObjectWidget {
  /// 위아래로 눌림을 받는 상자를 만듭니다.
  const new({required super.child, this.top = 0, this.bottom = 0, super.key});

  /// 위로 더 받는 높이.
  final double top;

  /// 아래로 더 받는 높이.
  final double bottom;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHitSlopPassage(top: top, bottom: bottom);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderHitSlopPassage)
        ..top = top
        ..bottom = bottom;
}

class _RenderHitSlopPassage extends RenderProxyBox {
  new({required this._top, required this._bottom});

  double _top;
  double _bottom;

  // 눌림 판정에서만 읽는 값이라 getter가 필요 없습니다.
  // ignore: avoid_setters_without_getters
  set top(double value) => _top = value;

  // 눌림 판정에서만 읽는 값이라 getter가 필요 없습니다.
  // ignore: avoid_setters_without_getters
  set bottom(double value) => _bottom = value;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final inside =
        position.dx >= 0 &&
        position.dx < size.width &&
        position.dy >= -_top &&
        position.dy < size.height + _bottom;
    if (!inside || size.height <= 0) return false;
    _exactPassDepth++;
    try {
      if (_hitTestClamped(result, child, size, position)) return true;
    } finally {
      _exactPassDepth--;
    }
    return _hitTestClamped(result, child, size, position);
  }
}
