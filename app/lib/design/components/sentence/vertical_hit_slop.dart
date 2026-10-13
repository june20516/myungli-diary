import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 최소 터치 크기(px). 명세 `term-token`·`depth-link`·`reaction-button` 모두 44입니다.
const double sentenceMinTarget = 44;

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
    super.key,
  });

  /// 눌림 영역의 최소 높이.
  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVerticalHitSlop(minHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderVerticalHitSlop).minHeight = minHeight;
}

class _RenderVerticalHitSlop extends RenderProxyBox {
  new(this._minHeight);

  double _minHeight;

  // 눌림 판정에서만 읽는 값이라 getter가 필요 없습니다.
  // ignore: avoid_setters_without_getters
  set minHeight(double value) => _minHeight = value;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final slop = math.max(0, (_minHeight - size.height) / 2);
    final inside =
        position.dx >= 0 &&
        position.dx < size.width &&
        position.dy >= -slop &&
        position.dy < size.height + slop;
    if (!inside) return false;
    // 자식의 판정은 자기 영역 안에서만 성립하므로, 넓힌 부분의 눌림은 가장자리로 모읍니다.
    final clamped = Offset(
      position.dx,
      position.dy.clamp(0, size.height - 0.01),
    );
    return result.addWithRawTransform(
      transform: null,
      position: position,
      hitTest: (result, _) =>
          child?.hitTest(result, position: clamped) ?? false,
    );
  }
}
