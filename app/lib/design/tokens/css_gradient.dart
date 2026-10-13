import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// CSS `linear-gradient(<angle>, …)`의 gradient line을 박스 크기에 맞게 계산합니다.
///
/// 각도는 위쪽이 0°이고 시계 방향입니다. 선은 박스 중심을 지나고,
/// 길이는 `|W·sinθ| + |H·cosθ|`입니다(CSS Images 3).
({Offset start, Offset end}) cssGradientLine(Rect bounds, double degrees) {
  final radians = degrees * math.pi / 180;
  final sin = math.sin(radians);
  final cos = math.cos(radians);
  final length = (bounds.width * sin).abs() + (bounds.height * cos).abs();
  final half = Offset(sin, -cos) * (length / 2);
  return (start: bounds.center - half, end: bounds.center + half);
}

/// 가로 그라데이션(`centerLeft` → `centerRight`)을 CSS 각도 그라데이션으로 바꿉니다.
///
/// 생성된 토큰이 `LinearGradient(begin: centerLeft, end: centerRight,
/// transform: CssAngleGradientTransform(160))`로 이 변환을 씁니다.
class CssAngleGradientTransform extends GradientTransform {
  /// [degrees]는 CSS 각도(도)입니다.
  const new(this.degrees);

  /// CSS 각도(도).
  final double degrees;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    if (bounds.isEmpty) {
      return null;
    }
    final line = cssGradientLine(bounds, degrees);
    final center = bounds.center;
    // 가로선의 반(W/2)을 CSS 선의 반(L/2)으로 보내는 회전·균등 확대, 중심 고정.
    final direction = line.end - line.start;
    final scale = direction.distance / bounds.width;
    final unit = direction / direction.distance;
    final a = scale * unit.dx;
    final b = scale * unit.dy;
    // x' = a·x - b·y + tx, y' = b·x + a·y + ty (열 기준 행렬)
    final tx = center.dx - (a * center.dx - b * center.dy);
    final ty = center.dy - (b * center.dx + a * center.dy);
    return Matrix4(a, b, 0, 0, -b, a, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is CssAngleGradientTransform && other.degrees == degrees;

  @override
  int get hashCode => degrees.hashCode;
}
