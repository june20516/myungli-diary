import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
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

/// `glint`(2600ms) 한 번(V131).
const Duration _sweep = Duration(milliseconds: 2600);

/// 띠가 지나가는 중인 대상 수.
int _glinting(WidgetTester tester) =>
    _glints(tester).where((render) => render.glinting).length;

/// 그려진 대상. 여러 element가 같은 render object를 가리키므로 한 번씩만 셉니다.
Set<RenderUnlockGlint> _glints(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderUnlockGlint>().toSet();

/// 맨 위에 대상 둘, 그 아래 긴 빈 자리를 둔 스크롤 화면.
Widget _app({
  MotionPrefs prefs = _normal,
  Duration firstDelay = Duration.zero,
  bool once = false,
  ScrollController? controller,
}) => MaterialApp(
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: Scaffold(
    body: MotionPrefsScope(
      prefs: prefs,
      child: UnlockGlintScope(
        firstDelay: firstDelay,
        once: once,
        child: Builder(
          builder: (context) => SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                const UnlockGlint(child: Text('판정 근거')),
                const UnlockGlint(child: Text('오늘은 용신의 날이고')),
                if (UnlockGlintScope.replacedOf(context))
                  const Text('mark', key: ValueKey('mark')),
                const SizedBox(height: 3000),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('unlock.glint 박자', () {
    testWidgets('처음 한 번, 그 뒤 앞 반짝임 시작에서 10초마다 대상 모두 함께 지나갑니다', (tester) async {
      await tester.pumpWidget(_app());
      // 보이는지 알리는 프레임 뒤 첫 박자(첫 기다림 0)가 잡힙니다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 900));
      expect(_glinting(tester), 2, reason: '첫 반짝임, 두 대상 함께');

      await tester.pump(_sweep);
      expect(_glinting(tester), 0, reason: '2600ms 뒤 끝남');

      // 첫 반짝임 시작에서 10초 직전에는 아직 지나가지 않습니다.
      await tester.pump(
        PatternValues.glintInterval -
            _sweep -
            const Duration(milliseconds: 950),
      );
      expect(_glinting(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 900));
      expect(_glinting(tester), 2, reason: '10초 박자');
    });

    testWidgets('첫 기다림(appear.seep)이 있으면 그 뒤에 첫 반짝임입니다', (tester) async {
      await tester.pumpWidget(
        _app(firstDelay: InteractionPattern.appearSeep.duration),
      );
      await tester.pump();
      await tester.pump(
        InteractionPattern.appearSeep.duration -
            const Duration(milliseconds: 20),
      );
      expect(_glinting(tester), 0, reason: '내용이 다 나타나기 전');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_glinting(tester), 2);
    });

    testWidgets('앱이 배경으로 가면 멈추고, 돌아오면 다음 10초 박자에 지나갑니다', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_glinting(tester), 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(_glinting(tester), 0, reason: '지나가던 띠를 지움');
      await tester.pump(const Duration(seconds: 40));
      expect(_glinting(tester), 0, reason: '배경에서는 박자 없음');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(
        PatternValues.glintInterval - const Duration(milliseconds: 100),
      );
      expect(_glinting(tester), 0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_glinting(tester), 2, reason: '돌아온 뒤 10초 박자');
    });

    testWidgets('위 route에 덮이면 멈추고, 닫히면 다시 이어집니다', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_glinting(tester), 2);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final popped = navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Text('위 화면')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 40));
      expect(_glinting(tester), 0, reason: '덮인 동안 박자 없음');

      navigator.pop();
      await popped;
      await tester.pumpAndSettle();
      await tester.pump(PatternValues.glintInterval);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_glinting(tester), 2, reason: '다시 보이면 10초 박자');
    });

    testWidgets('대상이 모두 화면 밖으로 스크롤되면 멈추고, 돌아오면 이어집니다', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_glinting(tester), 2);

      controller.jumpTo(1500);
      await tester.pump();
      expect(_glinting(tester), 0, reason: '화면 밖에서는 지움');
      await tester.pump(const Duration(seconds: 40));
      expect(_glinting(tester), 0);

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump(PatternValues.glintInterval);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_glinting(tester), 2);
    });

    testWidgets('지나가지 않는 동안에는 층을 만들지 않습니다', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.layers.whereType<ShaderMaskLayer>(), hasLength(2));
      await tester.pump(_sweep);
      expect(tester.layers.whereType<ShaderMaskLayer>(), isEmpty);
    });

    testWidgets('동작 줄이기면 박자도 띠도 없고 unlock.mark를 그리라고 알립니다', (tester) async {
      await tester.pumpWidget(_app(prefs: _reduce));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 5));
        expect(_glinting(tester), 0);
      }
      expect(_glints(tester), isEmpty);
      expect(find.byKey(const ValueKey('mark')), findsOneWidget);
    });

    testWidgets('박자가 빠지면(시트 닫힘) 끝나고 남은 타이머가 없습니다', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
      expect(_glints(tester), isEmpty);
    });
  });

  group('unlock.glint once(구매 직후 한 번, V135)', () {
    testWidgets('첫 기다림 뒤 한 번 지나가고 10초 박자로 반복하지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(firstDelay: InteractionPattern.appearSeep.duration, once: true),
      );
      await tester.pump();
      await tester.pump(
        InteractionPattern.appearSeep.duration -
            const Duration(milliseconds: 20),
      );
      expect(_glinting(tester), 0, reason: '내용이 다 나타나기 전');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_glinting(tester), 2, reason: '한 번 지나감');

      await tester.pump(_sweep);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 5));
        expect(_glinting(tester), 0, reason: '다시 지나가지 않음');
      }
    });

    testWidgets('동작 줄이기면 지나가지 않습니다', (tester) async {
      await tester.pumpWidget(_app(prefs: _reduce, once: true));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 5));
        expect(_glinting(tester), 0);
      }
      expect(_glints(tester), isEmpty);
    });
  });

  group('UnlockGlintBackdrop', () {
    const blue = Color(0xFF0000FF);
    const red = Color(0xFFFF0000);
    const boxSize = Size(300, 24);

    Widget box(Color color) => SizedBox.fromSize(
      size: boxSize,
      child: ColoredBox(color: color),
    );

    /// 띠 가운데가 지나는 상자 안 한 점(상자 세로 가운데).
    Offset bandMiddle(RenderUnlockGlint render) {
      final progress = InteractionPattern.unlockGlint.curve.transform(
        render.sweep.value,
      );
      final band = unlockGlintBand(boxSize, progress);
      final along = (band.bandStart + band.bandEnd) / 2;
      final y = boxSize.height / 2;
      return Offset((along - y * band.direction.dy) / band.direction.dx, y);
    }

    Future<Color> pixel(WidgetTester tester, Key key, Offset at) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!;
      });
      final index = (at.dy.round() * boxSize.width.round() + at.dx.round()) * 4;
      return Color.fromARGB(
        bytes!.getUint8(index + 3),
        bytes.getUint8(index),
        bytes.getUint8(index + 1),
        bytes.getUint8(index + 2),
      );
    }

    testWidgets('띠가 지나는 동안 바탕(용어 칩 바탕)은 칠하지 않고 그 위 글자는 칠합니다', (tester) async {
      // 위 줄: 바탕 표시 없는 빨간 상자(글자처럼 칠해짐). 아래 줄: 빨간 바탕 표시 위 왼쪽 절반에
      // 파란 "글자" 상자.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            brightness: Brightness.light,
            locale: const Locale('ko'),
          ),
          home: Scaffold(
            body: MotionPrefsScope(
              prefs: _normal,
              child: UnlockGlintScope(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(
                      key: const ValueKey('plain'),
                      child: UnlockGlint(child: box(red)),
                    ),
                    RepaintBoundary(
                      key: const ValueKey('backdrop'),
                      child: UnlockGlint(
                        child: UnlockGlintBackdrop(
                          decoration: const BoxDecoration(color: red),
                          child: SizedBox.fromSize(
                            size: boxSize,
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 150,
                                height: 24,
                                child: ColoredBox(color: blue),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1300));
      final renders = _glints(tester);
      expect(renders.every((render) => render.glinting), isTrue);
      final at = bandMiddle(renders.first);
      // 띠 가운데가 바탕만 있는 오른쪽 절반에 오는 프레임입니다.
      expect(at.dx, inInclusiveRange(150, boxSize.width - 1));

      expect(
        await pixel(tester, const ValueKey('plain'), at),
        isNot(red),
        reason: '표시 없는 자리는 띠 색',
      );
      expect(
        await pixel(tester, const ValueKey('backdrop'), at),
        red,
        reason: '바탕은 띠 없이 원래 색',
      );
    });

    testWidgets('바탕 위 글자는 띠 색으로 칠합니다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            brightness: Brightness.light,
            locale: const Locale('ko'),
          ),
          home: Scaffold(
            body: MotionPrefsScope(
              prefs: _normal,
              child: UnlockGlintScope(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: const ValueKey('backdrop'),
                    child: UnlockGlint(
                      child: UnlockGlintBackdrop(
                        decoration: const BoxDecoration(color: red),
                        child: box(blue),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1300));
      final render = _glints(tester).single;
      expect(render.glinting, isTrue);
      final color = await pixel(
        tester,
        const ValueKey('backdrop'),
        bandMiddle(render),
      );
      expect(color, isNot(blue), reason: '글자는 띠 색');
      expect(color, isNot(red), reason: '바탕이 글자를 덮지 않음');
    });
  });

  group('unlockGlintBand', () {
    test('띠는 진행 0에서 상자 앞 밖, 1에서 상자 뒤 밖이고 너비는 상자 너비의 30%입니다', () {
      for (final size in const [Size(300, 24), Size(300, 160)]) {
        final start = unlockGlintBand(size, 0);
        expect(start.bandEnd, closeTo(start.boxStart, 1e-9));
        expect(
          start.bandEnd - start.bandStart,
          closeTo(size.width * 0.3, 1e-9),
        );
        final end = unlockGlintBand(size, 1);
        expect(end.bandStart, closeTo(end.boxEnd, 1e-9));
        final middle = unlockGlintBand(size, 0.5);
        expect(middle.bandStart, greaterThan(middle.boxStart));
        expect(middle.bandEnd, lessThan(middle.boxEnd));
      }
    });

    test('방향은 CSS 100°(오른쪽으로 조금 아래)입니다', () {
      final band = unlockGlintBand(const Size(300, 24), 0.5);
      expect(band.direction.dx, greaterThan(0.98));
      expect(band.direction.dy, closeTo(0.1736, 1e-3));
    });
  });
}
