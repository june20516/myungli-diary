import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/tokens/css_gradient.dart';

/// 변환이 가로선(좌중→우중)을 보내는 시작·끝점.
({Offset start, Offset end}) _mapped(Rect bounds, double degrees) {
  final matrix = CssAngleGradientTransform(degrees).transform(bounds)!;
  Offset apply(Offset p) => MatrixUtils.transformPoint(matrix, p);

  return (start: apply(bounds.centerLeft), end: apply(bounds.centerRight));
}

void main() {
  const degrees = 160.0;
  final sin = math.sin(degrees * math.pi / 180);
  final cos = math.cos(degrees * math.pi / 180);

  void expectOffset(Offset actual, double x, double y, {double tol = 1e-9}) {
    expect(actual.dx, closeTo(x, tol));
    expect(actual.dy, closeTo(y, tol));
  }

  group('cssGradientLine', () {
    test('200×200: 길이 |W·sin|+|H·cos|, 중심 통과 (CSS 공식)', () {
      const bounds = Rect.fromLTWH(0, 0, 200, 200);
      final length = 200 * sin.abs() + 200 * cos.abs();
      final line = cssGradientLine(bounds, degrees);
      expectOffset(line.start, 100 - length / 2 * sin, 100 + length / 2 * cos);
      expectOffset(line.end, 100 + length / 2 * sin, 100 - length / 2 * cos);
      // 손으로 푼 값 (Python으로 계산, L = 256.3426...)
      expectOffset(line.start, 56.16284167, -20.44160264, tol: 1e-6);
      expectOffset(line.end, 143.83715833, 220.44160264, tol: 1e-6);
    });

    test('360×200: 정사각형이 아니면 길이가 달라진다', () {
      const bounds = Rect.fromLTWH(0, 0, 360, 200);
      final length = 360 * sin.abs() + 200 * cos.abs();
      final line = cssGradientLine(bounds, degrees);
      expectOffset(line.start, 180 - length / 2 * sin, 100 + length / 2 * cos);
      expectOffset(line.end, 180 + length / 2 * sin, 100 - length / 2 * cos);
      expectOffset(line.start, 126.80461940, -46.15310703, tol: 1e-6);
      expectOffset(line.end, 233.19538060, 246.15310703, tol: 1e-6);
    });

    test('원점이 아닌 박스: 중심이 (190, 120)', () {
      const bounds = Rect.fromLTWH(10, 20, 360, 200);
      final line = cssGradientLine(bounds, degrees);
      expectOffset(line.start, 136.80461940, -26.15310703, tol: 1e-6);
      expectOffset(line.end, 243.19538060, 266.15310703, tol: 1e-6);
      final mapped = _mapped(bounds, degrees);
      expectOffset(mapped.start, line.start.dx, line.start.dy);
      expectOffset(mapped.end, line.end.dx, line.end.dy);
    });

    test('0°는 아래에서 위, 90°는 왼쪽에서 오른쪽', () {
      const bounds = Rect.fromLTWH(10, 20, 100, 60);
      final up = cssGradientLine(bounds, 0);
      expectOffset(up.start, 60, 80);
      expectOffset(up.end, 60, 20);
      final right = cssGradientLine(bounds, 90);
      expectOffset(right.start, 10, 50);
      expectOffset(right.end, 110, 50);
    });
  });

  group('CssAngleGradientTransform', () {
    for (final size in [const Size(360, 200), const Size(200, 200)]) {
      test('${size.width.toInt()}×${size.height.toInt()}: 가로선이 CSS 선으로 간다', () {
        final bounds = Offset.zero & size;
        final expected = cssGradientLine(bounds, degrees);
        final mapped = _mapped(bounds, degrees);
        expectOffset(mapped.start, expected.start.dx, expected.start.dy);
        expectOffset(mapped.end, expected.end.dx, expected.end.dy);
      });
    }

    test('빈 박스는 변환하지 않는다', () {
      expect(const CssAngleGradientTransform(160).transform(Rect.zero), isNull);
    });
  });
}
