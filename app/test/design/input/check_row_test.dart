import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import 'input_harness.dart';

Widget _row({
  CheckRowVariant variant = CheckRowVariant.card,
  bool checked = false,
  ValueChanged<bool>? onChanged,
  VoidCallback? onView,
  String? viewLabel = '보기',
}) => Padding(
  padding: const EdgeInsets.all(20),
  child: CheckRow(
    variant: variant,
    label: '이용약관에 동의합니다',
    checked: checked,
    onChanged: onChanged,
    viewLabel: viewLabel,
    onView: onView,
  ),
);

void main() {
  group('check-row', () {
    testWidgets('줄을 누르면 반대 값으로 onChanged가 한 번 불립니다', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(inputApp(_row(onChanged: changes.add)));
      await tester.tap(find.text('이용약관에 동의합니다'));
      await tester.pumpAndSettle();
      expect(changes, [true]);
    });

    testWidgets('checked면 누를 때 false를 줍니다', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        inputApp(_row(checked: true, onChanged: changes.add)),
      );
      await tester.tap(find.byKey(CheckRow.boxKey));
      await tester.pumpAndSettle();
      expect(changes, [false]);
    });

    testWidgets('켜고 끌 때 selection 햅틱', (tester) async {
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_row(onChanged: (_) {})));
      await tester.tap(find.text('이용약관에 동의합니다'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets("'보기'를 누르면 onView만 불리고 onChanged와 checked는 그대로입니다", (
      tester,
    ) async {
      final changes = <bool>[];
      var viewed = 0;
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(
        inputApp(_row(onChanged: changes.add, onView: () => viewed++)),
      );
      await tester.tap(find.text('보기'));
      await tester.pumpAndSettle();
      expect(viewed, 1);
      expect(changes, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets("'보기'는 따로 초점을 받습니다", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_row(onChanged: (_) {}, onView: () {})));
      await tester.pumpAndSettle();
      final row = tester
          .getSemantics(find.bySemanticsLabel('이용약관에 동의합니다'))
          .getSemanticsData();
      expect(row.flagsCollection.isChecked, CheckedState.isFalse);
      final view = tester
          .getSemantics(find.bySemanticsLabel('보기'))
          .getSemanticsData();
      expect(view.flagsCollection.isLink, isTrue);
      // 서로 다른 노드입니다.
      expect(
        tester.getSemantics(find.bySemanticsLabel('보기')).id,
        isNot(tester.getSemantics(find.bySemanticsLabel('이용약관에 동의합니다')).id),
      );
      handle.dispose();
    });

    testWidgets("키보드 초점: Tab으로 줄 → '보기' 순서로 가고 각각 확정됩니다", (tester) async {
      final changes = <bool>[];
      var viewed = 0;
      await tester.pumpWidget(
        inputApp(_row(onChanged: changes.add, onView: () => viewed++)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, [true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(viewed, 1);
      expect(changes, [true]);
    });

    testWidgets('Semantics: 체크 상태가 checked 값을 따릅니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_row(checked: true, onChanged: (_) {})));
      await tester.pumpAndSettle();
      final flags = tester
          .getSemantics(find.bySemanticsLabel('이용약관에 동의합니다'))
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isChecked, CheckedState.isTrue);
      handle.dispose();
    });

    testWidgets('card는 bg.sheet 바탕 radius.md, 상자 24px입니다', (tester) async {
      await tester.pumpWidget(inputApp(_row(onChanged: (_) {})));
      await tester.pumpAndSettle();
      final colors = tester.element(find.byType(CheckRow)).tokens.colors;
      final deco =
          tester
                  .widget<DecoratedBox>(find.byKey(CheckRow.containerKey))
                  .decoration
              as BoxDecoration;
      expect(deco.color, colors.bgSheet);
      expect(deco.borderRadius, BorderRadius.circular(12));
      expect(tester.getSize(find.byKey(CheckRow.boxKey)), const Size(24, 24));
    });

    testWidgets('checked면 상자가 action.primary로 채워지고 체크가 그어집니다', (tester) async {
      await tester.pumpWidget(inputApp(_row(onChanged: (_) {})));
      await tester.pumpAndSettle();
      final colors = tester.element(find.byType(CheckRow)).tokens.colors;
      BoxDecoration box() =>
          tester.widget<DecoratedBox>(find.byKey(CheckRow.boxKey)).decoration
              as BoxDecoration;
      expect(box().color, isNot(colors.actionPrimary));
      expect((box().border! as Border).top.width, 1.5);
      await tester.pumpWidget(inputApp(_row(checked: true, onChanged: (_) {})));
      await tester.pumpAndSettle();
      expect(box().color, colors.actionPrimary);
      expect((box().border! as Border).top.color, colors.actionPrimary);
      expect(find.byKey(CheckRow.checkMarkKey), findsOneWidget);
    });

    testWidgets('inline은 바탕 없이 보기 링크도 숨기고 최소 높이 44입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          _row(
            variant: CheckRowVariant.inline,
            onChanged: (_) {},
            onView: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('보기'), findsNothing);
      final deco =
          tester
                  .widget<DecoratedBox>(find.byKey(CheckRow.containerKey))
                  .decoration
              as BoxDecoration;
      expect(deco.color, isNull);
      expect(
        tester.getSize(find.byKey(CheckRow.containerKey)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('onChanged가 null이면 disabled라 눌러도 아무 일이 없습니다', (tester) async {
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_row()));
      await tester.tap(find.text('이용약관에 동의합니다'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      final colors = tester.element(find.byType(CheckRow)).tokens.colors;
      expect(
        tester.widget<Text>(find.text('이용약관에 동의합니다')).style!.color,
        colors.disabledFg,
      );
    });

    testWidgets('viewLabel이 없으면 보기 링크를 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(_row(onChanged: (_) {}, viewLabel: null)),
      );
      expect(find.text('보기'), findsNothing);
    });

    testWidgets('긴 글자와 3.0배에서도 줄바꿈될 뿐 overflow가 없습니다', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: inputApp(_row(onChanged: (_) {}, onView: () {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
