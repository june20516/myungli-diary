import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

const _normal = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: false,
  lowEnd: false,
);
const _reduce = MotionPrefs(
  reduceMotion: true,
  reduceTransparency: false,
  lowEnd: false,
);
const _lowEnd = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: false,
  lowEnd: true,
);

const Key _rootKey = ValueKey('pattern-root');

Future<AnimationController> _pump(
  WidgetTester tester,
  InteractionPattern pattern,
  MotionPrefs prefs, {
  PatternOptions options = const PatternOptions(),
}) async {
  final controller = AnimationController(
    vsync: tester,
    duration: patternDuration(pattern, prefs),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(
        brightness: Brightness.light,
        locale: const Locale('ko'),
      ),
      home: Center(
        child: KeyedSubtree(
          key: _rootKey,
          child: animate(
            pattern,
            t: controller,
            prefs: prefs,
            options: options,
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    ),
  );
  return controller;
}

Finder _within(Finder matching) =>
    find.descendant(of: find.byKey(_rootKey), matching: matching);

double _opacityAt(WidgetTester tester) {
  final fade = tester.widgetList<FadeTransition>(
    _within(find.byType(FadeTransition)),
  );
  final opacity = tester.widgetList<Opacity>(_within(find.byType(Opacity)));
  return [
    ...fade.map((w) => w.opacity.value),
    ...opacity.map((w) => w.opacity),
  ].reduce((a, b) => a * b);
}

void main() {
  group('appearSeep', () {
    testWidgets('기본: 흐림과 투명도가 함께 바뀝니다', (tester) async {
      final c = await _pump(tester, InteractionPattern.appearSeep, _normal);
      c.value = 0.2;
      await tester.pump();
      expect(_within(find.byType(ImageFiltered)), findsOneWidget);
      expect(_opacityAt(tester), lessThan(1));
    });

    testWidgets('동작 줄이기: 이동·흐림 없이 투명도만 바뀝니다', (tester) async {
      final c = await _pump(tester, InteractionPattern.appearSeep, _reduce);
      c.value = 0.2;
      await tester.pump();
      expect(_within(find.byType(Transform)), findsNothing);
      expect(_within(find.byType(FractionalTranslation)), findsNothing);
      expect(_within(find.byType(ImageFiltered)), findsNothing);
      final mid = _opacityAt(tester);
      expect(mid, inInclusiveRange(0.01, 0.99));
      c.value = 1;
      await tester.pump();
      expect(_opacityAt(tester), 1);
    });

    testWidgets('저사양: 투명도만 바뀝니다', (tester) async {
      final c = await _pump(tester, InteractionPattern.appearSeep, _lowEnd);
      c.value = 0.3;
      await tester.pump();
      expect(_within(find.byType(ImageFiltered)), findsNothing);
    });
  });

  group('sealStamp', () {
    testWidgets('기본: 크기와 흐림이 있습니다', (tester) async {
      final c = await _pump(tester, InteractionPattern.sealStamp, _normal);
      c.value = 0.1;
      await tester.pump();
      expect(_within(find.byType(ImageFiltered)), findsOneWidget);
      expect(_within(find.byType(Transform)), findsOneWidget);
    });

    testWidgets('저사양(no-blur): 흐림만 빼고 크기 변화는 유지', (tester) async {
      final c = await _pump(tester, InteractionPattern.sealStamp, _lowEnd);
      c.value = 0.1;
      await tester.pump();
      expect(_within(find.byType(ImageFiltered)), findsNothing);
      expect(_within(find.byType(Transform)), findsOneWidget);
    });

    testWidgets('동작 줄이기: 투명도만', (tester) async {
      final c = await _pump(tester, InteractionPattern.sealStamp, _reduce);
      c.value = 0.1;
      await tester.pump();
      expect(_within(find.byType(Transform)), findsNothing);
      expect(_within(find.byType(ImageFiltered)), findsNothing);
    });
  });

  group('sheetEnter', () {
    testWidgets('기본: 아래에서 올라옵니다', (tester) async {
      final c = await _pump(tester, InteractionPattern.sheetEnter, _normal);
      c.value = 0;
      await tester.pump();
      final start = tester.widget<FractionalTranslation>(
        _within(find.byType(FractionalTranslation)),
      );
      expect(start.translation.dy, 1);
    });

    testWidgets('동작 줄이기: 이동 없이 투명도만', (tester) async {
      final c = await _pump(tester, InteractionPattern.sheetEnter, _reduce);
      c.value = 0.5;
      await tester.pump();
      expect(_within(find.byType(FractionalTranslation)), findsNothing);
    });
  });

  group('focusRing (reduceMotion: instant)', () {
    test('동작 줄이기면 시간이 0입니다', () {
      expect(
        patternDuration(InteractionPattern.focusRing, _reduce),
        Duration.zero,
      );
      expect(
        patternDuration(InteractionPattern.focusRing, _normal),
        const Duration(milliseconds: 200),
      );
    });

    test('opacity-only 패턴은 동작 줄이기에서도 시간이 그대로입니다', () {
      expect(
        patternDuration(InteractionPattern.appearSeep, _reduce),
        const Duration(milliseconds: 320),
      );
    });

    testWidgets('동작 줄이기: 진행 중이어도 곧바로 끝 값입니다', (tester) async {
      final c = await _pump(tester, InteractionPattern.focusRing, _reduce);
      c.value = 0.01;
      await tester.pump();
      final box = tester.widget<DecoratedBox>(
        _within(find.byType(DecoratedBox)).last,
      );
      final border = (box.decoration as BoxDecoration).border! as Border;
      expect(border.top.width, 2);
    });
  });

  group('loadingBreathe', () {
    testWidgets('투명도가 0.55~1 사이입니다', (tester) async {
      final c = await _pump(tester, InteractionPattern.loadingBreathe, _normal);
      c.value = 0;
      await tester.pump();
      expect(_opacityAt(tester), closeTo(0.55, 0.001));
      c.value = 1;
      await tester.pump();
      expect(_opacityAt(tester), closeTo(1, 0.001));
    });
  });

  group('markUnderlineGrow', () {
    testWidgets('가운데에서 가로로 자랍니다', (tester) async {
      final c = await _pump(
        tester,
        InteractionPattern.markUnderlineGrow,
        _normal,
      );
      c.value = 0;
      await tester.pump();
      final transform = tester.widget<Transform>(
        _within(find.byType(Transform)),
      );
      expect(transform.alignment, Alignment.center);
      expect(transform.transform.storage[0], closeTo(0, 0.001));
    });
  });

  group('MotionPrefs.of', () {
    testWidgets('disableAnimations를 reduceMotion으로 읽습니다', (tester) async {
      late MotionPrefs prefs;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            highContrast: true,
          ),
          child: Builder(
            builder: (context) {
              prefs = MotionPrefs.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(prefs.reduceMotion, isTrue);
      expect(prefs.reduceTransparency, isTrue);
      expect(prefs.lowEnd, isFalse);
    });

    testWidgets('MotionPrefsScope가 있으면 그 값을 씁니다', (tester) async {
      late MotionPrefs prefs;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: MotionPrefsScope(
            prefs: _lowEnd,
            child: Builder(
              builder: (context) {
                prefs = MotionPrefs.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(prefs.lowEnd, isTrue);
    });
  });
}
