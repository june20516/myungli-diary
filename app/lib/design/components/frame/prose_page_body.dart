import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 안내 글 화면(계산 기준 등)의 본문 골격. 문단을 위에서부터 쌓고 전체가 스크롤됩니다.
///
/// 앱 바 아래 inner 페이지 여백(좌우 `space.20`, 위 `space.24`, 아래 `space.32`)과 문단 사이
/// `space.20`을 한 곳에서 정합니다. 그리지 않을 문단은 [paragraphs]에 넣지 않으면 자리도
/// 남지 않습니다. 높이가 0인 문단(예 나타나기 전 대기 중인 skeleton)에도 간격을 두지
/// 않아, 문단이 나타나거나 사라져도 다른 문단 사이 간격은 한 번(`space.20`)입니다.
/// 큰 글자·작은 화면에서도 잘리지 않고 스크롤로 닿습니다.
///
/// IA 컴포넌트가 아닌 레이아웃으로, 값은 `frame.md` "안내 글 본문"(2.4.0, 결정 V34)이
/// 정합니다(좌우 `space.20`, 위 `space.24`, 아래 `space.32`, 문단 사이 `space.20`).
class ProsePageBody extends StatelessWidget {
  /// 본문 골격을 만듭니다.
  const new({required this.paragraphs, super.key});

  /// 화면에 놓을 문단(대개 `sentence-block` `body` 또는 그 자리의 skeleton).
  final List<Widget> paragraphs;

  /// 문단 사이 간격(px).
  static const double paragraphGap = Space.s20;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.s20,
        Space.s24,
        Space.s20,
        Space.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, paragraph) in paragraphs.indexed)
            if (index == 0)
              paragraph
            else
              _GapBefore(gap: paragraphGap, child: paragraph),
        ],
      ),
    );
  }
}

/// [child] 위에 [gap]을 둡니다. [child]의 높이가 0이면 간격도 두지 않습니다.
class _GapBefore extends SingleChildRenderObjectWidget {
  const new({required this.gap, required Widget super.child});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGapBefore(gap);

  @override
  void updateRenderObject(BuildContext context, _RenderGapBefore renderObject) {
    renderObject.gap = gap;
  }
}

class _RenderGapBefore extends RenderShiftedBox {
  new(this._gap) : super(null);

  double _gap;

  /// 자식 위 간격(px).
  double get gap => _gap;

  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// [childHeight]가 0보다 크면 간격, 아니면 0.
  double _gapFor(double childHeight) => childHeight > 0 ? _gap : 0;

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(
        minHeight: 0,
        maxHeight: constraints.hasBoundedHeight
            ? math.max(0, constraints.maxHeight - _gap)
            : double.infinity,
      );

  @override
  double computeMinIntrinsicHeight(double width) {
    final height = child?.getMinIntrinsicHeight(width) ?? 0;
    return height + _gapFor(height);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final height = child?.getMaxIntrinsicHeight(width) ?? 0;
    return height + _gapFor(height);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final size = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(
      Size(size.width, size.height + _gapFor(size.height)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    final gap = _gapFor(child.size.height);
    (child.parentData! as BoxParentData).offset = Offset(0, gap);
    size = constraints.constrain(
      Size(child.size.width, child.size.height + gap),
    );
  }
}
