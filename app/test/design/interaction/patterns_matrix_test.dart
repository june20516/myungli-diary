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

const Key _rootKey = ValueKey('matrix-root');

/// 패턴 한 줄의 기대: 모드별 흐림·이동(이동·크기) 유무와 끝 투명도.
class _Row {
  const new(
    this.name,
    this.pattern, {
    required this.blurNormal,
    required this.motionNormal,
    required this.blurLowEnd,
    required this.motionLowEnd,
    this.endOpacityNormal = 1,
    this.endOpacityReduce = 1,
    this.options = const PatternOptions(),
  });

  final String name;
  final InteractionPattern pattern;
  final bool blurNormal;
  final bool motionNormal;
  final bool blurLowEnd;
  final bool motionLowEnd;
  final double endOpacityNormal;
  final double endOpacityReduce;
  final PatternOptions options;
}

const _rows = <_Row>[
  _Row(
    'appearSeep',
    InteractionPattern.appearSeep,
    blurNormal: true,
    motionNormal: false,
    blurLowEnd: false,
    motionLowEnd: false,
  ),
  _Row(
    'disappearSeep',
    InteractionPattern.disappearSeep,
    blurNormal: true,
    motionNormal: false,
    blurLowEnd: false,
    motionLowEnd: false,
    endOpacityNormal: 0,
    endOpacityReduce: 0,
  ),
  _Row(
    'selectSeepSlide incoming',
    InteractionPattern.selectSeepSlide,
    blurNormal: true,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: false,
  ),
  _Row(
    'selectSeepSlide outgoing',
    InteractionPattern.selectSeepSlide,
    blurNormal: true,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: false,
    endOpacityNormal: 0,
    endOpacityReduce: 0,
    options: PatternOptions(outgoing: true),
  ),
  _Row(
    'loadingBreathe',
    InteractionPattern.loadingBreathe,
    blurNormal: false,
    motionNormal: false,
    blurLowEnd: false,
    motionLowEnd: false,
  ),
  _Row(
    'sealStamp',
    InteractionPattern.sealStamp,
    blurNormal: true,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: true,
  ),
  _Row(
    'sealErase',
    InteractionPattern.sealErase,
    blurNormal: true,
    motionNormal: false,
    blurLowEnd: false,
    motionLowEnd: false,
    endOpacityNormal: 0,
    endOpacityReduce: 0,
  ),
  _Row(
    'markUnderlineGrow',
    InteractionPattern.markUnderlineGrow,
    blurNormal: false,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: true,
  ),
  _Row(
    'sheetEnter',
    InteractionPattern.sheetEnter,
    blurNormal: false,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: true,
  ),
  _Row(
    'sheetExit',
    InteractionPattern.sheetExit,
    blurNormal: false,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: true,
    endOpacityReduce: 0,
  ),
  _Row(
    'sheetStack screen',
    InteractionPattern.sheetStack,
    blurNormal: false,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: true,
  ),
  _Row(
    'sheetStack sheet',
    InteractionPattern.sheetStack,
    blurNormal: false,
    motionNormal: true,
    blurLowEnd: false,
    motionLowEnd: true,
    options: PatternOptions(stackLayer: StackLayer.sheet),
  ),
];

Future<AnimationController> _pump(
  WidgetTester tester,
  InteractionPattern pattern,
  MotionPrefs prefs,
  PatternOptions options,
) async {
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

bool _hasBlur(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(_within(find.byType(ImageFiltered)))
    .any((w) => w.enabled);

bool _hasMotion(WidgetTester tester) =>
    _within(find.byType(Transform)).evaluate().isNotEmpty ||
    _within(find.byType(FractionalTranslation)).evaluate().isNotEmpty;

double _opacity(WidgetTester tester) => tester
    .widgetList<Opacity>(_within(find.byType(Opacity)))
    .fold(1, (product, w) => product * w.opacity);

void main() {
  group('패턴 × 모드 표', () {
    for (final row in _rows) {
      testWidgets('${row.name}: 흐림·이동 유무와 끝 값', (tester) async {
        const mid = 0.4;
        for (final (label, prefs, blur, motion) in [
          ('기본', _normal, row.blurNormal, row.motionNormal),
          ('저사양', _lowEnd, row.blurLowEnd, row.motionLowEnd),
          ('동작 줄이기', _reduce, false, false),
        ]) {
          final c = await _pump(tester, row.pattern, prefs, row.options);
          c.value = mid;
          await tester.pump();
          expect(_hasBlur(tester), blur, reason: '${row.name} $label 흐림');
          expect(_hasMotion(tester), motion, reason: '${row.name} $label 이동');
          c.value = 1;
          await tester.pump();
          expect(
            _opacity(tester),
            closeTo(
              prefs == _reduce ? row.endOpacityReduce : row.endOpacityNormal,
              0.001,
            ),
            reason: '${row.name} $label 끝 투명도',
          );
        }
      });
    }

    testWidgets('loadingBreathe: 모든 모드에서 투명도만(0.55~1)', (tester) async {
      for (final prefs in [_normal, _lowEnd, _reduce]) {
        final c = await _pump(
          tester,
          InteractionPattern.loadingBreathe,
          prefs,
          const PatternOptions(),
        );
        c.value = 0;
        await tester.pump();
        expect(_opacity(tester), closeTo(0.55, 0.001));
      }
    });

    testWidgets('loadingBreathe: index가 150ms 어긋남을 줍니다', (tester) async {
      final c = await _pump(
        tester,
        InteractionPattern.loadingBreathe,
        _normal,
        const PatternOptions(index: 1),
      );
      c.value = 0;
      await tester.pump();
      // 한 주기 3600ms 중 150ms 뒤처지면 하한(0.55)보다 위에서 시작합니다.
      expect(_opacity(tester), greaterThan(0.55));
    });
  });

  group('sheetStack 덮개 밝기', () {
    for (final (layer, brightness) in [
      (StackLayer.screen, PatternValues.stackScreenBrightness),
      (StackLayer.sheet, PatternValues.stackSheetBrightness),
    ]) {
      testWidgets('$layer: 끝에서 덮개 알파가 1 - 밝기', (tester) async {
        final c = await _pump(
          tester,
          InteractionPattern.sheetStack,
          _normal,
          PatternOptions(stackLayer: layer),
        );
        c.value = 1;
        await tester.pump();
        final veil = tester
            .widgetList<ColoredBox>(_within(find.byType(ColoredBox)))
            .single;
        expect(veil.color.a, closeTo(1 - brightness, 0.001));
      });
    }

    testWidgets('sheet 층은 위로 30px, 크기 0.94', (tester) async {
      final c = await _pump(
        tester,
        InteractionPattern.sheetStack,
        _normal,
        const PatternOptions(stackLayer: StackLayer.sheet),
      );
      c.value = 1;
      await tester.pump();
      final matrix = tester
          .widget<Transform>(_within(find.byType(Transform)))
          .transform;
      expect(matrix.getTranslation().y, closeTo(-30, 0.001));
      expect(matrix.storage[0], closeTo(0.94, 0.001));
    });

    testWidgets('screen 층은 크기 0.92', (tester) async {
      final c = await _pump(
        tester,
        InteractionPattern.sheetStack,
        _normal,
        const PatternOptions(),
      );
      c.value = 1;
      await tester.pump();
      final matrix = tester
          .widget<Transform>(_within(find.byType(Transform)))
          .transform;
      expect(matrix.storage[0], closeTo(0.92, 0.001));
    });
  });

  group('selectSeepSlide', () {
    testWidgets('들어오는 표시는 이전 쪽에서 거리의 15%만큼 미끄러집니다', (tester) async {
      final c = await _pump(
        tester,
        InteractionPattern.selectSeepSlide,
        _normal,
        const PatternOptions(),
      );
      c.value = 0;
      await tester.pump();
      final slide = tester.widget<FractionalTranslation>(
        _within(find.byType(FractionalTranslation)),
      );
      expect(slide.translation.dx, closeTo(-0.15, 0.001));
      c.value = 1;
      await tester.pump();
      expect(
        tester
            .widget<FractionalTranslation>(
              _within(find.byType(FractionalTranslation)),
            )
            .translation
            .dx,
        closeTo(0, 0.001),
      );
    });

    testWidgets('나가는 표시는 fade(280ms) 안에 사라집니다', (tester) async {
      final c = await _pump(
        tester,
        InteractionPattern.selectSeepSlide,
        _normal,
        const PatternOptions(outgoing: true),
      );
      // 280/340 이후에는 이미 완전히 사라진 상태입니다.
      c.value = 0.9;
      await tester.pump();
      expect(_opacity(tester), closeTo(0, 0.001));
    });
  });

  group('pressInk', () {
    Future<RenderObject> inkRender(
      WidgetTester tester,
      MotionPrefs prefs, {
      double release = 0,
      double t = 0.5,
    }) async {
      final releaseController = AnimationController(
        vsync: tester,
        value: release,
      );
      addTearDown(releaseController.dispose);
      final c = await _pump(
        tester,
        InteractionPattern.pressInk,
        prefs,
        PatternOptions(release: releaseController),
      );
      c.value = t;
      await tester.pump();
      return tester.renderObject(_within(find.byType(CustomPaint)).last);
    }

    testWidgets('번짐: 원형 얼룩을 그립니다', (tester) async {
      final render = await inkRender(tester, _normal);
      expect(render, paints..circle());
      expect(render, isNot(paints..rect()));
    });

    testWidgets('동작 줄이기: 번짐 없이 전체 면의 투명도만 씁니다', (tester) async {
      final render = await inkRender(tester, _reduce);
      expect(render, paints..rect());
      expect(render, isNot(paints..circle()));
    });

    testWidgets('다 뗀 뒤에는 아무것도 그리지 않습니다', (tester) async {
      final render = await inkRender(tester, _normal, release: 1, t: 1);
      expect(render, isNot(paints..circle()));
      expect(render, isNot(paints..rect()));
    });

    testWidgets('떼는 중에는 더 크게 번지며 옅어집니다', (tester) async {
      final render = await inkRender(tester, _normal, release: 0.5, t: 1);
      expect(render, paints..circle());
    });
  });

  group('animateScrim', () {
    Future<AnimationController> pumpScrim(
      WidgetTester tester,
      InteractionPattern pattern,
    ) async {
      final c = AnimationController(vsync: tester, duration: pattern.duration);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            brightness: Brightness.light,
            locale: const Locale('ko'),
          ),
          home: KeyedSubtree(
            key: _rootKey,
            child: animateScrim(pattern, t: c, prefs: _normal),
          ),
        ),
      );
      return c;
    }

    testWidgets('sheetEnter: 0 → 1, fade(280ms)에 끝납니다', (tester) async {
      final c = await pumpScrim(tester, InteractionPattern.sheetEnter);
      c.value = 0;
      await tester.pump();
      expect(_opacity(tester), closeTo(0, 0.001));
      c.value = 280 / 420;
      await tester.pump();
      expect(_opacity(tester), closeTo(1, 0.001));
      c.value = 1;
      await tester.pump();
      expect(_opacity(tester), closeTo(1, 0.001));
    });

    testWidgets('sheetExit: 1 → 0, fade(280ms)에 끝납니다', (tester) async {
      final c = await pumpScrim(tester, InteractionPattern.sheetExit);
      c.value = 0;
      await tester.pump();
      expect(_opacity(tester), closeTo(1, 0.001));
      c.value = 280 / 320;
      await tester.pump();
      expect(_opacity(tester), closeTo(0, 0.001));
    });
  });
}
