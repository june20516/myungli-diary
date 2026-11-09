import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 꼬리표가 놓인 기둥이 표의 어느 끝인지(`daeun-table` `currentLabel`, V53).
enum TagEdge {
  /// 표 가운데 기둥. 넘친 꼬리표는 양쪽으로 고르게 넘칩니다.
  none,

  /// 표 시작 쪽 끝 기둥. 넘친 꼬리표를 시작 쪽 끝에 맞춥니다.
  start,

  /// 표 끝 쪽 끝 기둥. 넘친 꼬리표를 끝 쪽 끝에 맞춥니다.
  end;

  /// [count]개 줄에서 [index]번째 기둥의 끝. 기둥이 하나면 시작 쪽에 맞춥니다.
  static TagEdge of(int index, int count) {
    if (index == 0) return start;
    if (index == count - 1) return end;
    return none;
  }
}

/// 기둥 위 꼬리표 자리(`daeun-table` `currentLabel`, V53).
///
/// 자기 폭은 기둥 폭이고 높이는 꼬리표 높이입니다. 꼬리표는 [maxWidth]까지 한 줄로 넓어질 수
/// 있고, 기둥보다 좁으면 가운데, 넓으면 이웃 위 빈 꼬리표 자리로 넘칩니다. 표 끝 기둥([edge])
/// 에서는 표 밖으로 나가지 않게 그 끝에 맞춥니다. 꼬리표는 줄에 하나뿐이라 넘쳐도 겹칠 것이
/// 없습니다.
class TagSlot extends SingleChildRenderObjectWidget {
  /// 꼬리표 자리를 만듭니다.
  const new({
    required this.maxWidth,
    required this.edge,
    required super.child,
    super.key,
  });

  /// 꼬리표 최대 폭.
  final double maxWidth;

  /// 표 끝 맞춤.
  final TagEdge edge;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTagSlot(maxWidth, edge, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTagSlot)
      ..maxWidth = maxWidth
      ..edge = edge
      ..textDirection = Directionality.of(context);
  }
}

class _RenderTagSlot extends RenderShiftedBox {
  new(this._maxWidth, this._edge, this._textDirection) : super(null);

  double _maxWidth;

  double get maxWidth => _maxWidth;

  set maxWidth(double value) {
    if (_maxWidth == value) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  TagEdge _edge;

  TagEdge get edge => _edge;

  set edge(TagEdge value) {
    if (_edge == value) return;
    _edge = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;

  TextDirection get textDirection => _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    final width = constraints.maxWidth;
    if (child == null) {
      size = constraints.constrain(Size(width, 0));
      return;
    }
    child.layout(BoxConstraints(maxWidth: _maxWidth), parentUsesSize: true);
    size = constraints.constrain(Size(width, child.size.height));
    final centered = (size.width - child.size.width) / 2;
    final overflows = child.size.width > size.width;
    // 시작 쪽 끝이면 왼쪽(LTR)에, 끝 쪽 끝이면 오른쪽(LTR)에 맞춥니다. RTL이면 반대입니다.
    final alignLeft = switch (_edge) {
      TagEdge.none => null,
      TagEdge.start => _textDirection == TextDirection.ltr,
      TagEdge.end => _textDirection == TextDirection.rtl,
    };
    final dx = !overflows || alignLeft == null
        ? centered
        : alignLeft
        ? 0.0
        : size.width - child.size.width;
    (child.parentData! as BoxParentData).offset = Offset(dx, 0);
  }
}
