import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

void main() {
  testWidgets('위젯: 다 자란 얼룩이 pressInkRadius 반지름으로 그려집니다(smoke)', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          brightness: Brightness.light,
          locale: const Locale('ko'),
        ),
        home: Center(
          child: SizedBox(
            width: 100,
            height: 40,
            child: animate(
              InteractionPattern.pressInk,
              t: controller,
              prefs: const MotionPrefs(
                reduceMotion: false,
                reduceTransparency: false,
                lowEnd: false,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    controller.value = 1;
    await tester.pump();
    final expected = math.sqrt(50 * 50 + 20 * 20) / 0.7;
    final paintFinder = find.descendant(
      of: find.byType(SizedBox),
      matching: find.byType(CustomPaint),
    );
    expect(
      tester.renderObject(paintFinder.first),
      paints..circle(radius: expected),
    );
  });

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
