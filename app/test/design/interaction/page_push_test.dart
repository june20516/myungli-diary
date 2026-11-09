import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/interaction/page_push_transition.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

const Key _firstKey = ValueKey('first');
const Key _secondKey = ValueKey('second');

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _navigatorKey,
      theme: buildTheme(
        brightness: Brightness.light,
        locale: const Locale('ko'),
      ),
      home: const ColoredBox(key: _firstKey, color: Color(0xFFFFFFFF)),
    ),
  );
}

void _pushSecond() {
  _navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) =>
          const ColoredBox(key: _secondKey, color: Color(0xFFEEEEEE)),
    ),
  );
}

double _x(WidgetTester tester, Key key) =>
    tester.getTopLeft(find.byKey(key)).dx;

/// 새 화면에 걸린 투명도(FadeTransition을 모두 곱한 값).
double _opacity(WidgetTester tester) {
  final fades = tester.widgetList<FadeTransition>(
    find.ancestor(
      of: find.byKey(_secondKey),
      matching: find.byType(FadeTransition),
    ),
  );
  return fades.fold(1, (value, fade) => value * fade.opacity.value);
}

void main() {
  test('두 플랫폼이 같은 page.push builder를 씁니다(A110)', () {
    final theme = buildTheme(
      brightness: Brightness.light,
      locale: const Locale('ko'),
    );
    final builders = theme.pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<PagePushTransitionsBuilder>());
    expect(builders[TargetPlatform.iOS], isA<PagePushTransitionsBuilder>());
    expect(
      const PagePushTransitionsBuilder().transitionDuration,
      Motion.pageDuration,
    );
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${platform.name}: 오른쪽 24px에서 밀려 들어오며 나타나고 뒤 화면은 그대로입니다', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await _pumpApp(tester);
        _pushSecond();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final x = _x(tester, _secondKey);
        expect(x, greaterThan(0));
        expect(x, lessThanOrEqualTo(Motion.pageOffset));
        final eased = Motion.pageEasing.transform(120 / 320);
        expect(x, closeTo(Motion.pageOffset * (1 - eased), 0.5));
        expect(_opacity(tester), closeTo(eased, 0.01));
        // 뒤 화면은 움직이지 않습니다.
        expect(_x(tester, _firstKey), 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(_x(tester, _secondKey), 0);
        expect(_opacity(tester), 1);
        await tester.pumpAndSettle();

        // 뒤로 가기는 거꾸로 재생합니다.
        _navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        final back = _x(tester, _secondKey);
        expect(back, greaterThan(0));
        expect(back, lessThanOrEqualTo(Motion.pageOffset));
        expect(_x(tester, _firstKey), 0);
        await tester.pumpAndSettle();
        expect(find.byKey(_secondKey), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('${platform.name}: 동작 줄이기면 이동 없이 투명도만 바뀝니다', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      try {
        await _pumpApp(tester);
        _pushSecond();
        await tester.pump();
        for (var ms = 0; ms < 320; ms += 40) {
          await tester.pump(const Duration(milliseconds: 40));
          expect(_x(tester, _secondKey), 0, reason: '$ms ms');
        }
        await tester.pumpAndSettle();
        expect(_x(tester, _secondKey), 0);
        expect(_opacity(tester), 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('${platform.name}: 전환이 끝난 화면 위에는 Opacity와 Transform이 남지 않습니다', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await _pumpApp(tester);
        _pushSecond();
        await tester.pumpAndSettle();
        for (final type in [Opacity, Transform]) {
          expect(
            find.ancestor(
              of: find.byKey(_secondKey),
              matching: find.byType(type),
            ),
            findsNothing,
            reason: '$type',
          );
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('iOS: 왼쪽 가장자리에서 밀면 뒤로 갑니다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pumpApp(tester);
      _pushSecond();
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(_secondKey), findsNothing);
      expect(find.byKey(_firstKey), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('android: 가장자리 밀기로는 뒤로 가지 않습니다(시스템 뒤로 가기를 씀)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pumpApp(tester);
      _pushSecond();
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(_secondKey), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
