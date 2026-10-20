import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';

import '../input/input_harness.dart';

const Map<FiveElement, String> _names = {
  FiveElement.wood: '목',
  FiveElement.fire: '화',
  FiveElement.earth: '토',
  FiveElement.metal: '금',
  FiveElement.water: '수',
};

/// 받은 순서를 일부러 섞습니다(수·목·금·화·토).
Widget _bar(Map<FiveElement, double> values) => SizedBox(
  width: 320,
  child: OhaengBar(
    semanticLabel: '목 1, 화 2',
    items: [
      for (final element in [
        FiveElement.water,
        FiveElement.wood,
        FiveElement.metal,
        FiveElement.fire,
        FiveElement.earth,
      ])
        OhaengBarItem(
          element: element,
          name: _names[element]!,
          value: values[element] ?? 0,
          count: '${values[element] ?? 0}',
        ),
    ],
  ),
);

/// 막대 칸(색)과 그 너비(왼쪽부터).
List<(Color, double)> _segments(WidgetTester tester) {
  final boxes = find.descendant(
    of: find.byKey(OhaengBar.barKey),
    matching: find.byType(DecoratedBox),
  );
  return [
    for (final element in boxes.evaluate())
      (
        ((element.widget as DecoratedBox).decoration as BoxDecoration).color!,
        (element.renderObject! as RenderBox).size.width,
      ),
  ];
}

void main() {
  testWidgets('막대·범례 순서는 받은 순서와 상관없이 목·화·토·금·수', (tester) async {
    await tester.pumpWidget(
      inputApp(
        Center(
          child: _bar({
            FiveElement.wood: 1,
            FiveElement.fire: 1,
            FiveElement.earth: 1,
            FiveElement.metal: 1,
            FiveElement.water: 1,
          }),
        ),
      ),
    );
    final colors = tester.element(find.byType(OhaengBar)).tokens.colors;
    expect(
      [for (final (color, _) in _segments(tester)) color],
      [for (final e in FiveElement.values) ohaengSwatchOf(colors, e)],
    );
    final xs = [
      for (final name in ['목', '화', '토', '금', '수'])
        tester.getCenter(find.text(name)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
  });

  testWidgets('칸 길이는 값에 비례하고 높이는 10', (tester) async {
    await tester.pumpWidget(
      inputApp(Center(child: _bar({FiveElement.wood: 1, FiveElement.fire: 3}))),
    );
    final segments = _segments(tester);
    expect(segments, hasLength(2));
    expect(segments[1].$2 / segments[0].$2, closeTo(3, 0.05));
    // 칸마다 막대 높이를 그대로 채웁니다.
    for (final element in [FiveElement.wood, FiveElement.fire]) {
      expect(
        tester.getSize(find.byKey(OhaengBar.segmentKey(element))).height,
        OhaengBar.barHeight,
      );
    }
    expect(
      tester.getSize(find.byKey(OhaengBar.barKey)).height,
      OhaengBar.barHeight,
    );
  });

  testWidgets('zero: 0인 오행은 칸 없이 견본 0.35·개수 text.secondary', (tester) async {
    await tester.pumpWidget(
      inputApp(Center(child: _bar({FiveElement.fire: 2}))),
    );
    expect(_segments(tester), hasLength(1));
    final colors = tester.element(find.byType(OhaengBar)).tokens.colors;
    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity)
        .toList();
    expect(opacities.where((o) => o == 0.35), hasLength(4));
    expect(
      tester.widget<Text>(find.text('0.0').first).style?.color,
      colors.textSecondary,
    );
  });

  testWidgets('스크린리더는 그림 하나로 라벨을 읽습니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(Center(child: _bar({}))));
    final node = tester.getSemantics(find.bySemanticsLabel('목 1, 화 2'));
    expect(node.getSemanticsData().flagsCollection.isImage, isTrue);
    expect(find.bySemanticsLabel('목'), findsNothing);
    handle.dispose();
  });
}
