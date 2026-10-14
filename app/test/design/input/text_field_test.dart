import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import 'input_harness.dart';

BoxDecoration _decoration(Finder finder, WidgetTester tester) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

Finder _ring() => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.position == DecorationPosition.foreground,
);

void main() {
  group('text-field', () {
    testWidgets('maxLength를 넘게 칠 수 없습니다', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        inputApp(
          Center(
            child: MyungliTextField(
              label: '호칭',
              maxLength: 4,
              onChanged: changes.add,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '가나다라마바');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '가나다라',
      );
      expect(changes.last, '가나다라');
      expect(find.text('4/4'), findsOneWidget);
    });

    testWidgets('칸 전체(위·아래 가장자리, 왼쪽 여백)를 눌러도 포커스가 갑니다', (tester) async {
      await tester.pumpWidget(
        inputApp(const Center(child: MyungliTextField(label: '호칭'))),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      final box = find.byKey(MyungliTextField.containerKey);
      final rect = tester.getRect(box);
      expect(rect.height, greaterThanOrEqualTo(48));
      for (final point in [
        rect.topLeft + const Offset(40, 2),
        rect.bottomLeft + const Offset(40, -2),
        rect.centerLeft + const Offset(3, 0),
      ]) {
        field.focusNode!.unfocus();
        await tester.pump();
        expect(field.focusNode!.hasFocus, isFalse);
        await tester.tapAt(point);
        await tester.pump();
        expect(field.focusNode!.hasFocus, isTrue, reason: '$point');
      }
    });

    testWidgets('disabled 칸은 눌러도 포커스가 가지 않습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const Center(child: MyungliTextField(label: '호칭', enabled: false)),
        ),
      );
      await tester.tapAt(
        tester.getTopLeft(find.byKey(MyungliTextField.containerKey)) +
            const Offset(40, 2),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isFalse,
      );
    });

    testWidgets('글자 수 표시는 "글자 수 n/max"로 읽힙니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          const Center(child: MyungliTextField(label: '호칭', maxLength: 10)),
        ),
      );
      await tester.enterText(find.byType(TextField), '달이');
      await tester.pump();
      expect(find.bySemanticsLabel('글자 수 2/10'), findsOneWidget);
      expect(find.bySemanticsLabel('2/10'), findsNothing);
      handle.dispose();
    });

    testWidgets('onSubmitted를 넘깁니다', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: MyungliTextField(
              label: '호칭',
              onSubmitted: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '달');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, '달');
    });

    testWidgets('바깥 controller를 쓰고 hint를 보입니다', (tester) async {
      final controller = TextEditingController(text: '처음');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        inputApp(
          Center(
            child: MyungliTextField(
              label: '호칭',
              hint: '예: 달',
              controller: controller,
            ),
          ),
        ),
      );
      expect(find.text('처음'), findsOneWidget);
      controller.clear();
      await tester.pump();
      expect(find.text('예: 달'), findsOneWidget);
    });

    testWidgets('평소는 1px line, 포커스면 2px action.primary이고 바탕은 그대로입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        inputApp(const Center(child: MyungliTextField(label: '호칭'))),
      );
      await tester.pumpAndSettle();
      final colors = tester
          .element(find.byType(MyungliTextField))
          .tokens
          .colors;
      final bgBefore = _decoration(
        find.byKey(MyungliTextField.containerKey),
        tester,
      ).color;
      expect(bgBefore, colors.bgSheet);
      var ring = _decoration(_ring(), tester).border! as Border;
      expect(ring.top.width, 1);
      expect(ring.top.color, colors.line);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      ring = _decoration(_ring(), tester).border! as Border;
      expect(ring.top.width, 2);
      expect(ring.top.color, colors.actionPrimary);
      expect(
        _decoration(find.byKey(MyungliTextField.containerKey), tester).color,
        bgBefore,
        reason: '포커스에 바탕색을 바꾸지 않음',
      );
    });

    testWidgets('error면 2px text.primary 테두리입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const Center(child: MyungliTextField(label: '호칭', error: true)),
        ),
      );
      await tester.pumpAndSettle();
      final colors = tester
          .element(find.byType(MyungliTextField))
          .tokens
          .colors;
      final ring = _decoration(_ring(), tester).border! as Border;
      expect(ring.top.width, 2);
      expect(ring.top.color, colors.textPrimary);
    });

    testWidgets('높이는 최소 52이고 글자 3.0배에서는 커집니다', (tester) async {
      await tester.pumpWidget(
        inputApp(const Center(child: MyungliTextField(label: '호칭'))),
      );
      expect(
        tester.getSize(find.byKey(MyungliTextField.containerKey)).height,
        52,
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: inputApp(const Center(child: MyungliTextField(label: '호칭'))),
        ),
      );
      expect(
        tester.getSize(find.byKey(MyungliTextField.containerKey)).height,
        greaterThan(52),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('지우기는 글자가 있고 포커스가 있을 때만 보이고 누르면 비웁니다', (tester) async {
      await tester.pumpWidget(
        inputApp(const Center(child: MyungliTextField(label: '호칭'))),
      );
      expect(find.byKey(MyungliTextField.clearKey), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        find.byKey(MyungliTextField.clearKey),
        findsNothing,
        reason: '포커스만 있고 글자 없음',
      );
      await tester.enterText(find.byType(TextField), '달');
      await tester.pump();
      expect(find.byKey(MyungliTextField.clearKey), findsOneWidget);
      await tester.tap(find.byKey(MyungliTextField.clearKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byKey(MyungliTextField.clearKey), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
        reason: '지운 뒤에도 입력을 이어 갑니다',
      );
    });

    testWidgets('포커스를 잃으면 지우기가 사라집니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const Column(
            children: [
              MyungliTextField(label: '호칭'),
              TextField(key: ValueKey('other')),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(MyungliTextField), '달');
      await tester.pump();
      expect(find.byKey(MyungliTextField.clearKey), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('other')));
      await tester.pump();
      expect(find.byKey(MyungliTextField.clearKey), findsNothing);
    });

    testWidgets('Semantics: textfield이고 라벨을 읽으며 지우기는 button입니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(const Center(child: MyungliTextField(label: '호칭'))),
      );
      final data = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.label, contains('호칭'));
      await tester.enterText(find.byType(TextField), '달');
      await tester.pump();
      final clear = tester
          .getSemantics(find.byKey(MyungliTextField.clearKey))
          .getSemanticsData();
      expect(clear.flagsCollection.isButton, isTrue);
      expect(clear.label, '지우기');
      expect(
        tester.getSize(find.byKey(MyungliTextField.clearKey)).shortestSide,
        greaterThanOrEqualTo(48),
      );
      handle.dispose();
    });

    testWidgets('enabled=false면 입력할 수 없고 disabled 색입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const Center(child: MyungliTextField(label: '호칭', enabled: false)),
        ),
      );
      final colors = tester
          .element(find.byType(MyungliTextField))
          .tokens
          .colors;
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        _decoration(find.byKey(MyungliTextField.containerKey), tester).color,
        colors.disabledBg,
      );
    });
  });
}
