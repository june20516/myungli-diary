import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import 'input_harness.dart';

const List<SegmentedItem<String>> _items = [
  SegmentedItem('f', '여성'),
  SegmentedItem('m', '남성'),
  SegmentedItem('x', '기타'),
];

Widget _segmented({
  String selected = 'f',
  ValueChanged<String>? onChanged,
  List<SegmentedItem<String>> items = _items,
}) => Padding(
  padding: const EdgeInsets.all(20),
  child: Segmented<String>(
    items: items,
    selected: selected,
    onChanged: onChanged,
    label: '성별',
  ),
);

void main() {
  group('segmented', () {
    test('항목은 2~4개입니다', () {
      expect(
        () => Segmented<int>(
          items: const [SegmentedItem(1, 'a')],
          selected: 1,
          onChanged: (_) {},
          label: 'x',
        ),
        throwsAssertionError,
      );
      expect(
        () => Segmented<int>(
          items: [for (var i = 0; i < 5; i++) SegmentedItem(i, '$i')],
          selected: 0,
          onChanged: (_) {},
          label: 'x',
        ),
        throwsAssertionError,
      );
    });

    test('selected가 items에 없으면 assert입니다', () {
      expect(
        () => Segmented<String>(
          items: _items,
          selected: 'z',
          onChanged: (_) {},
          label: 'x',
        ),
        throwsAssertionError,
      );
    });

    testWidgets('pressed: 누르는 동안 press.ink 얼룩이 번지고 뗀 뒤 사라집니다', (tester) async {
      await tester.pumpWidget(inputApp(_segmented(onChanged: (_) {})));
      await tester.pumpAndSettle();
      final layer = inkLayer(find.byKey(Segmented.itemKey(1)));
      expect(paintsInk(tester, layer), isFalse);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Segmented.itemKey(1))),
      );
      // 눌림 인식(100ms) 뒤 얼룩이 번지기 시작합니다.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(paintsInk(tester, layer), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(paintsInk(tester, layer), isFalse);
    });

    testWidgets('다른 항목을 누르면 onChanged가 그 값으로 한 번 불립니다', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(inputApp(_segmented(onChanged: changes.add)));
      await tester.tap(find.text('남성'));
      await tester.pumpAndSettle();
      expect(changes, ['m']);
    });

    testWidgets('이미 선택된 항목을 누르면 onChanged도 햅틱도 없습니다', (tester) async {
      final changes = <String>[];
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_segmented(onChanged: changes.add)));
      await tester.tap(find.text('여성'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets('선택이 바뀌면 selection 햅틱 한 번', (tester) async {
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_segmented(onChanged: (_) {})));
      await tester.tap(find.text('남성'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('onChanged가 null이면 눌러도 아무 일이 없습니다', (tester) async {
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_segmented()));
      await tester.tap(find.text('남성'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });

    testWidgets('키보드 Enter로 항목을 고릅니다', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(inputApp(_segmented(onChanged: changes.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['m']);
    });

    testWidgets('항목 너비가 같고 트랙 높이는 최소 40입니다', (tester) async {
      await tester.pumpWidget(inputApp(_segmented(onChanged: (_) {})));
      await tester.pumpAndSettle();
      final widths = [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byKey(Segmented.itemKey(i))).width,
      ];
      expect(widths[1], closeTo(widths[0], 0.01));
      expect(widths[2], closeTo(widths[0], 0.01));
      expect(tester.getSize(find.byKey(Segmented.trackKey)).height, 40);
    });

    testWidgets('Semantics: radio-group 안의 항목마다 선택된 것만 checked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_segmented(onChanged: (_) {})));
      await tester.pumpAndSettle();
      CheckedState checked(String label) {
        final flags = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .flagsCollection;
        expect(flags.isInMutuallyExclusiveGroup, isTrue);
        return flags.isChecked;
      }

      expect(checked('여성'), CheckedState.isTrue);
      expect(checked('남성'), CheckedState.isFalse);
      expect(checked('기타'), CheckedState.isFalse);
      handle.dispose();
    });

    testWidgets('그룹 Semantics 라벨은 무엇을 고르는지입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_segmented(onChanged: (_) {})));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('성별'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('항목 눌림 영역은 위아래로 넓어져 44 이상입니다', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(inputApp(_segmented(onChanged: changes.add)));
      await tester.pumpAndSettle();
      final item = find.byKey(Segmented.itemKey(1));
      expect(tester.getSize(item).height, 40, reason: '항목 칸은 트랙 높이 전체');
      // 트랙 위 끝에서 1.5px 위(44 - 40의 절반은 2px)를 눌러도 항목이 받습니다.
      final top = tester.getTopLeft(item);
      final width = tester.getSize(item).width;
      await tester.tapAt(top + Offset(width / 2, -1.5));
      await tester.pumpAndSettle();
      expect(changes, ['m']);
    });

    testWidgets('선택된 글자는 on-primary, 나머지는 text.secondary입니다', (tester) async {
      await tester.pumpWidget(inputApp(_segmented(onChanged: (_) {})));
      await tester.pumpAndSettle();
      final colors = tester
          .element(find.byType(Segmented<String>))
          .tokens
          .colors;
      expect(
        tester.widget<Text>(find.text('여성')).style!.color,
        colors.actionOnPrimary,
      );
      expect(
        tester.widget<Text>(find.text('남성')).style!.color,
        colors.textSecondary,
      );
    });

    testWidgets('선택을 옮기면 표시가 선택 항목으로 옮겨 갑니다', (tester) async {
      await tester.pumpWidget(inputApp(_segmented(onChanged: (_) {})));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(Segmented.itemKey(0)),
          matching: find.byKey(Segmented.indicatorKey),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(
        inputApp(_segmented(selected: 'x', onChanged: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // 이전 표시는 사라지는 중이라 아직 남아 있고, 새 표시는 들어오는 중입니다.
      expect(find.byKey(Segmented.indicatorKey), findsNWidgets(2));
      await tester.pumpAndSettle();
      expect(find.byKey(Segmented.indicatorKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Segmented.itemKey(2)),
          matching: find.byKey(Segmented.indicatorKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('글자 3.0배에서 항목 높이가 커지고 overflow가 없습니다', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: inputApp(_segmented(onChanged: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(Segmented.trackKey)).height,
        greaterThan(40),
      );
    });
  });
}
