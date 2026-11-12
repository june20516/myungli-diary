import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/interaction/stick_to_end_on_grow.dart';

/// 높이 [tail]인 끝 상자를 단 세로 목록(화면 600).
Widget _list(ScrollController controller, double tail) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(400, 600)),
    child: StickToEndOnGrow(
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          children: [
            const SizedBox(height: 1000),
            SizedBox(height: tail),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('끝에 있었으면 내용이 자라도 새 끝에 붙습니다', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_list(controller, 0));
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    final before = controller.position.maxScrollExtent;

    await tester.pumpWidget(_list(controller, 200));
    await tester.pump();
    expect(controller.position.maxScrollExtent, greaterThan(before));
    expect(controller.position.pixels, controller.position.maxScrollExtent);
  });

  testWidgets('끝에서 떨어져 있으면 그대로 둡니다', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_list(controller, 0));
    await tester.pump();
    controller.jumpTo(100);
    await tester.pump();

    await tester.pumpWidget(_list(controller, 200));
    await tester.pump();
    expect(controller.position.pixels, 100);
  });
}
