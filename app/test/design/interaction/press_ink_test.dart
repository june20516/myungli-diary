import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';

void main() {
  group('pressInkRadius', () {
    const size = Size(100, 40);
    final farthest = math.sqrt(100 * 100 + 40 * 40);

    test('가운데를 눌러 다 자란 반지름은 가장 먼 모서리 ÷ 0.7입니다', () {
      expect(
        pressInkRadius(
          size: size,
          origin: Alignment.center,
          grow: 1,
          release: 0,
        ),
        closeTo(farthest / 2 / 0.7, 0.001),
      );
    });

    test('모서리를 누르면 반대 모서리까지 닿는 반지름이 됩니다', () {
      expect(
        pressInkRadius(
          size: size,
          origin: Alignment.topLeft,
          grow: 1,
          release: 0,
        ),
        closeTo(farthest / 0.7, 0.001),
      );
    });

    test('덜 자란 채 떼도 release 끝에는 다 자란 반지름의 1.15배입니다', () {
      final full = pressInkRadius(
        size: size,
        origin: Alignment.center,
        grow: 1,
        release: 0,
      );
      expect(
        pressInkRadius(
          size: size,
          origin: Alignment.center,
          grow: 0.3,
          release: 1,
        ),
        closeTo(full * 1.15, 0.001),
      );
    });

    test('뗀 뒤 반지름은 줄어들지 않고 이어 자랍니다', () {
      double at(double release) => pressInkRadius(
        size: size,
        origin: Alignment.center,
        grow: 0.4,
        release: release,
      );
      expect(at(0.5), greaterThan(at(0)));
      expect(at(1), greaterThan(at(0.5)));
    });
  });
}
