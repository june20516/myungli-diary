import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 최소 터치 크기(px). 명세 `term-token`·`depth-link`·`reaction-button` 모두 44입니다.
const double sentenceMinTarget = 44;

/// [HitSlopPassage]가 넓힘 없이 먼저 판정하는 동안의 판정 결과. 이 결과로 판정되는 동안 안쪽
/// [VerticalHitSlop]은 넓히지 않습니다.
///
/// 전역 상태 대신 판정 결과에 표시를 둡니다. 상자 판정은 받은 결과 객체를 그대로 자식에게 넘기므로
/// (`addWithPaintOffset` 등) 표시가 안쪽까지 이어집니다. 결과를 새로 감싸는 경계(sliver 등)를
/// 지나면 표시가 끊겨 넓혀 판정하므로, [HitSlopPassage] 안에는 상자 자식만 둡니다. 감싼 결과는
/// 원래 결과와 같은 경로에 항목을 더합니다.
final class _ExactPassResult extends BoxHitTestResult {
  new wrap(super.result) : super.wrap();
}

/// [child]를 자기 좌표 [position]에서 판정합니다. 넓힌 부분의 눌림은 자식 판정이 자기 영역 안에서만
/// 성립하므로 가장자리로 모아 넘깁니다.
bool _hitChildClamped(
  BoxHitTestResult result,
  RenderBox child,
  Offset position,
) {
  final size = child.size;
  return child.hitTest(
    result,
    position: Offset(
      position.dx.clamp(0, size.width - 0.01),
      position.dy.clamp(0, size.height - 0.01),
    ),
  );
}

/// 자식이 [minHeight]보다 낮으면 위아래로 눌리는 영역만 넓힙니다. 모양과 배치는 그대로입니다.
///
/// 문장 속 글자는 줄 높이(24~28px)가 44px보다 낮아 터치 영역이 모자랍니다. 명세는
/// "줄 높이까지 위아래로 넓힘"이라, 레이아웃을 바꾸지 않고 눌림 판정만 넓힙니다.
/// 넓힌 영역은 위아래 이웃 줄의 글자 위까지 겹칠 수 있습니다. [HitSlopPassage] 밖에서는 겹친 곳을
/// 이 글자가 받고(두 줄에 걸친 가까운 용어끼리는 먼저 판정되는 쪽이 받음), [HitSlopPassage] 안에서는
/// 그 위치를 실제로 덮은 이웃이 먼저 받고 아무도 덮지 않았을 때만 넓힌 영역이 받습니다. 문단 맨 위·맨
/// 아래 줄은 문단 영역 밖이라 넓혀도 닿지 않는 한계가 있습니다(인라인 글자의 한계, 부모를
/// [HitSlopPassage]로 감싸면 닿음).
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
    final widen = result is! _ExactPassResult;
    final slop = widen ? math.max(0, (_minHeight - size.height) / 2) : 0;
    final extra = widen ? math.max(0, _minWidth - size.width) : 0;
    final slopStart = _widenLeftOnly ? extra : extra / 2;
    final slopEnd = _widenLeftOnly ? 0 : extra / 2;
    final inside =
        position.dx >= -slopStart &&
        position.dx < size.width + slopEnd &&
        position.dy >= -slop &&
        position.dy < size.height + slop;
    final child = this.child;
    if (!inside || child == null) return false;
    return result.addWithRawTransform(
      transform: null,
      position: position,
      hitTest: (result, position) => _hitChildClamped(result, child, position),
    );
  }
}

/// 자식 안의 [VerticalHitSlop]이 넓힌 눌림이 이 상자 경계에서 막히지 않게, 위 [top]과 아래
/// [bottom]만큼 바깥의 눌림을 받아 자식 가장자리로 모아 넘깁니다.
///
/// 보통 상자는 자기 영역 밖의 눌림을 자식에게 넘기지 않습니다. 넓힐 자리가 부모 영역 끝에 붙은
/// 글줄(예: 날짜 머리 맨 아래 줄의 덕일 알약, 행운 칩 줄)이면 그 부모를 이것으로 감쌉니다. 자식 영역
/// 안의 눌림은 그대로 넘기고, 넓힌 부분은 세로만 가장자리로 모으므로(가로 위치 그대로) 그 위치의
/// 자식이 받습니다. 받는 자식이 없으면 이 상자도 받지 않습니다.
///
/// [reserveSpace]가 false(기본)면 모양과 배치는 그대로이고 여유는 상자 밖입니다(부모 경계 밖의
/// 눌림은 부모가 받아 넘길 때만 닿음). true면 여유를 레이아웃 높이에 넣어 자식 위아래에 빈자리를
/// 둡니다(행운 칩 줄처럼 여유 자리가 카드 안이어야 할 때).
///
/// 판정은 두 번입니다. 먼저 안쪽 [VerticalHitSlop]을 넓히지 않고 판정해 그 위치를 실제로 덮은
/// 자식이 받고, 아무도 덮지 않았을 때만 넓혀 다시 판정합니다. 그래서 줄 넘김으로 위아래에 쌓인
/// 알약끼리 아래 알약의 넓힘이 윗 알약을 가로채지 않습니다(옆 칸과 겹치는 쪽은 넓히지 않음).
///
/// 전제: 안쪽에 [HitTestBehavior.translucent] 자손을 두지 않습니다. translucent 자손은 첫 판정이
/// 실패해도 결과에 자기 항목을 더하고 false를 돌려줄 수 있어, 둘째 판정에서 같은 항목이 다시
/// 더해집니다. 지금 감싼 자리(날짜 머리, 신살 칸, 행운 칩 줄)에는 없습니다.
class HitSlopPassage extends SingleChildRenderObjectWidget {
  /// 위아래로 눌림을 받는 상자를 만듭니다.
  const new({
    required super.child,
    this.top = 0,
    this.bottom = 0,
    this.reserveSpace = false,
    super.key,
  });

  /// 위로 더 받는 높이.
  final double top;

  /// 아래로 더 받는 높이.
  final double bottom;

  /// 여유([top], [bottom])를 레이아웃 높이에 넣을지.
  final bool reserveSpace;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHitSlopPassage(
        top: top,
        bottom: bottom,
        reserveSpace: reserveSpace,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderHitSlopPassage)
        ..top = top
        ..bottom = bottom
        ..reserveSpace = reserveSpace;
}

class _RenderHitSlopPassage extends RenderShiftedBox {
  new({required this._top, required this._bottom, required this._reserveSpace})
    : super(null);

  double _top;
  double _bottom;
  bool _reserveSpace;

  set top(double value) {
    if (_top == value) return;
    _top = value;
    if (_reserveSpace) markNeedsLayout();
  }

  double get top => _top;

  set bottom(double value) {
    if (_bottom == value) return;
    _bottom = value;
    if (_reserveSpace) markNeedsLayout();
  }

  double get bottom => _bottom;

  set reserveSpace(bool value) {
    if (_reserveSpace == value) return;
    _reserveSpace = value;
    markNeedsLayout();
  }

  bool get reserveSpace => _reserveSpace;

  /// 레이아웃에 넣는 위아래 여유의 합.
  double get _reserved => _reserveSpace ? _top + _bottom : 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(width) + _reserved;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(width) + _reserved;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    final childSize = child == null
        ? Size.zero
        : child.getDryLayout(constraints);
    return constraints.constrain(
      Size(childSize.width, childSize.height + _reserved),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, _reserved));
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      _reserveSpace ? _top : 0,
    );
    size = constraints.constrain(
      Size(child.size.width, child.size.height + _reserved),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || child.size.height <= 0) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    final local = position - offset;
    final inside =
        local.dx >= 0 &&
        local.dx < child.size.width &&
        local.dy >= -_top &&
        local.dy < child.size.height + _bottom;
    if (!inside) return false;
    bool pass(BoxHitTestResult result) => result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, local) => _hitChildClamped(result, child, local),
    );
    return pass(_ExactPassResult.wrap(result)) || pass(result);
  }
}
