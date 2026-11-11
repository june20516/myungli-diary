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

/// `breathe`(1800ms) 한 번.
const Duration _sweep = Duration(milliseconds: 1800);

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
  ScrollController? controller,
}) => MaterialApp(
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: Scaffold(
    body: MotionPrefsScope(
      prefs: prefs,
      child: UnlockGlintScope(
        firstDelay: firstDelay,
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
    testWidgets('처음 한 번, 그 뒤 앞 반짝임 시작에서 15초마다 대상 모두 함께 지나갑니다', (tester) async {
      await tester.pumpWidget(_app());
      // 보이는지 알리는 프레임 뒤 첫 박자(첫 기다림 0)가 잡힙니다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 900));
      expect(_glinting(tester), 2, reason: '첫 반짝임, 두 대상 함께');

      await tester.pump(_sweep);
      expect(_glinting(tester), 0, reason: '1800ms 뒤 끝남');

      // 첫 반짝임 시작에서 15초 직전에는 아직 지나가지 않습니다.
      await tester.pump(
        PatternValues.glintInterval -
            _sweep -
            const Duration(milliseconds: 950),
      );
      expect(_glinting(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 900));
      expect(_glinting(tester), 2, reason: '15초 박자');
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

    testWidgets('앱이 배경으로 가면 멈추고, 돌아오면 다음 15초 박자에 지나갑니다', (tester) async {
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
      expect(_glinting(tester), 2, reason: '돌아온 뒤 15초 박자');
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
      expect(_glinting(tester), 2, reason: '다시 보이면 15초 박자');
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
