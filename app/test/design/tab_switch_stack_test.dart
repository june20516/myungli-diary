import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/components/frame/tab_switch_stack.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

const MotionPrefs _normal = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: false,
  lowEnd: false,
);

const MotionPrefs _reduced = MotionPrefs(
  reduceMotion: true,
  reduceTransparency: false,
  lowEnd: false,
);

/// 탭 셸처럼 탭 바와 [TabSwitchStack]이 같은 index를 나눠 씁니다.
class _Harness extends StatefulWidget {
  const new({required this.taps, this.scrollController});

  /// 화면마다 눌린 횟수.
  final List<int> taps;

  /// 0번 화면 목록의 스크롤(상태 유지 확인용).
  final ScrollController? scrollController;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;

  void select(int value) => setState(() => index = value);

  Widget _screen(int i) => Semantics(
    container: true,
    label: '화면 $i',
    child: GestureDetector(
      key: ValueKey('screen-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.taps[i]++,
      child: i == 0
          ? ListView(
              controller: widget.scrollController,
              children: [
                for (var row = 0; row < 50; row++)
                  SizedBox(height: 40, child: Text('줄 $row')),
              ],
            )
          : const SizedBox.expand(),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: TabSwitchStack(
          index: index,
          children: [for (var i = 0; i < 4; i++) _screen(i)],
        ),
      ),
      MyungliTabBar(index: index, onSelect: select),
    ],
  );
}

Future<_HarnessState> _pump(
  WidgetTester tester, {
  MotionPrefs prefs = _normal,
  List<int>? taps,
  ScrollController? scrollController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(
          brightness: Brightness.light,
          locale: const Locale('ko'),
        ),
        home: MotionPrefsScope(
          prefs: prefs,
          child: Material(
            child: _Harness(
              taps: taps ?? [0, 0, 0, 0],
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// [i] 화면의 지금 투명도. 화면이 offstage면 null입니다.
double? _opacity(WidgetTester tester, int i) {
  final screen = find.byKey(ValueKey('screen-$i'));
  if (screen.evaluate().isEmpty) return null;
  return tester
      .widget<Opacity>(
        find.ancestor(of: screen, matching: find.byType(Opacity)).first,
      )
      .opacity;
}

double _eased(double linear) =>
    InteractionPattern.tabSwitch.curve.transform(linear);

Future<void> _tapTab(WidgetTester tester, int i) async {
  await tester.tap(find.byKey(ValueKey('tab-bar.tab.$i')));
  // 탭을 누른 프레임. 전환은 이 프레임에서 시작합니다.
  await tester.pump();
}

void main() {
  group('tab.switch (V104)', () {
    testWidgets('처음에는 지금 탭만 보이고 나머지는 offstage입니다', (tester) async {
      await _pump(tester);
      expect(_opacity(tester, 0), 1);
      for (final i in [1, 2, 3]) {
        expect(_opacity(tester, i), isNull, reason: '화면 $i');
      }
    });

    testWidgets('200ms 동안 앞 화면 1→0, 새 화면 0→1로 겹치고 이동과 크기는 그대로입니다', (
      tester,
    ) async {
      await _pump(tester);
      final before = tester.getRect(find.byKey(const ValueKey('screen-0')));
      await _tapTab(tester, 2);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester, 0), closeTo(1 - _eased(0.5), 0.001));
      expect(_opacity(tester, 2), closeTo(_eased(0.5), 0.001));
      expect(tester.getRect(find.byKey(const ValueKey('screen-0'))), before);
      expect(tester.getRect(find.byKey(const ValueKey('screen-2'))), before);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('screen-2')),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester, 2), 1);
      expect(_opacity(tester, 0), isNull, reason: '끝나면 앞 화면은 offstage');
    });

    testWidgets('탭 바 도장 seal.stamp와 같은 프레임에 시작합니다', (tester) async {
      await _pump(tester);
      await _tapTab(tester, 1);
      const elapsed = Duration(milliseconds: 100);
      await tester.pump(elapsed);

      // 화면: 200ms 중 100ms.
      expect(_opacity(tester, 1), closeTo(_eased(0.5), 0.001));
      // 도장: 520ms 중 100ms, 첫 구간(0~35%)의 투명도.
      final progress =
          elapsed.inMicroseconds /
          InteractionPattern.sealStamp.duration.inMicroseconds;
      final firstLeg = PatternValues.stampFirstEasing.transform(
        progress / PatternValues.stampSplit,
      );
      final sealOpacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.descendant(
                    of: find.byKey(const ValueKey('tab-bar.tab.1')),
                    matching: find.byType(Seal),
                  ),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(
        sealOpacity,
        closeTo(PatternValues.stampSplitOpacity * firstLeg, 0.001),
      );
    });

    testWidgets('전환 중 다른 탭을 누르면 보이던 화면은 지금 투명도에서 0으로, 새 화면은 0에서 1로', (
      tester,
    ) async {
      await _pump(tester);
      await _tapTab(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      final zeroAt = _opacity(tester, 0)!;
      final oneAt = _opacity(tester, 1)!;

      await _tapTab(tester, 3);
      expect(_opacity(tester, 0), closeTo(zeroAt, 0.001), reason: '멈춘 자리');
      expect(_opacity(tester, 1), closeTo(oneAt, 0.001), reason: '멈춘 자리');
      expect(_opacity(tester, 3), 0);

      await tester.pump(const Duration(milliseconds: 100));
      final v = _eased(0.5);
      expect(_opacity(tester, 0), closeTo(zeroAt * (1 - v), 0.001));
      expect(_opacity(tester, 1), closeTo(oneAt * (1 - v), 0.001));
      expect(_opacity(tester, 3), closeTo(v, 0.001));

      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester, 3), 1);
      expect(_opacity(tester, 0), isNull);
      expect(_opacity(tester, 1), isNull);
    });

    testWidgets('전환 중 앞 탭으로 돌아가면 그 화면은 지금 투명도에서 이어 올라갑니다(A122)', (
      tester,
    ) async {
      await _pump(tester);
      await _tapTab(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      final zeroAt = _opacity(tester, 0)!;

      await _tapTab(tester, 0);
      expect(_opacity(tester, 0), closeTo(zeroAt, 0.001), reason: '0으로 끊지 않음');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _opacity(tester, 0),
        closeTo(zeroAt + (1 - zeroAt) * _eased(0.5), 0.001),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester, 0), 1);
      expect(_opacity(tester, 1), isNull);
    });

    testWidgets('이미 선택된 탭을 다시 누르면 전환이 없습니다', (tester) async {
      final state = await _pump(tester);
      state.select(0);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_opacity(tester, 0), 1);
    });

    testWidgets('전환 중에는 새 화면만 터치를 받고 앞 화면은 스크린리더에서 숨습니다', (tester) async {
      final handle = tester.ensureSemantics();
      final taps = [0, 0, 0, 0];
      await _pump(tester, taps: taps);
      await _tapTab(tester, 2);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester, 0), greaterThan(0.5), reason: '앞 화면이 아직 진함');

      await tester.tapAt(const Offset(200, 100));
      expect(taps, [0, 0, 1, 0]);
      expect(find.semantics.byLabel('화면 0'), findsNothing);
      expect(find.semantics.byLabel('화면 2'), findsOneWidget);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('앞 탭의 스크롤 위치는 다녀와도 그대로입니다', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(tester, scrollController: controller);
      controller.jumpTo(300);
      await tester.pump();
      await _tapTab(tester, 1);
      await tester.pumpAndSettle();
      await _tapTab(tester, 0);
      await tester.pumpAndSettle();
      expect(controller.offset, 300);
    });

    testWidgets('동작 줄이기에서도 원래 투명도만이라 200ms 그대로 겹칩니다', (tester) async {
      await _pump(tester, prefs: _reduced);
      await _tapTab(tester, 1);
      await tester.pump(Motion.short ~/ 2);
      expect(_opacity(tester, 0), closeTo(1 - _eased(0.5), 0.001));
      expect(_opacity(tester, 1), closeTo(_eased(0.5), 0.001));
      await tester.pump(Motion.short ~/ 2);
      expect(_opacity(tester, 1), 1);
    });
  });
}
