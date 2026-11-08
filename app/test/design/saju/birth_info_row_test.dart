import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/saju/birth_info_row.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

Widget _row({bool timeUnknown = false, double width = 360}) => SizedBox(
  width: width,
  child: BirthInfoRow(
    calendarTag: '양력',
    date: '1990.5.15',
    hourGlyph: timeUnknown ? null : '未',
    hourName: timeUnknown ? null : '미시',
    time: timeUnknown ? null : '오후 2:30',
    gender: '남성',
    timeUnknown: timeUnknown,
  ),
);

Widget _scaled(Widget child, double scale) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
  child: child,
);

void main() {
  testWidgets('칸 셋은 날짜, 시진, 성별 순으로 한 줄에 놓이고 칸 사이는 세로선입니다', (tester) async {
    await tester.pumpWidget(inputApp(_row(width: 600)));
    final rects = [
      for (final key in BirthInfoRow.cellKeys) tester.getRect(find.byKey(key)),
    ];
    expect(rects[0].right, lessThan(rects[1].left));
    expect(rects[1].right, lessThan(rects[2].left));
    expect(
      rects[1].center.dy,
      moreOrLessEquals(rects[0].center.dy, epsilon: 1),
    );
    // 쉼표나 가운뎃점 같은 글자는 없습니다.
    expect(find.textContaining(','), findsNothing);
    expect(find.textContaining('·'), findsNothing);
    final dividers = find.byKey(BirthInfoRow.dividerKey);
    expect(dividers, findsNWidgets(2));
    final divider = tester.getRect(dividers.first);
    expect(divider.width, BirthInfoRow.dividerWidth);
    expect(divider.height, BirthInfoRow.dividerHeight);
    // 선 좌우는 space.12, 칸에서 떨어져 있습니다.
    expect(rects[1].left - divider.right, Space.s12);
    expect(divider.left - rects[0].right, Space.s12);
  });

  testWidgets('세로선은 color.line, 시진 태그는 누를 수 없는 ganji 변형입니다', (tester) async {
    await tester.pumpWidget(inputApp(_row(width: 600)));
    final context = tester.element(find.byType(BirthInfoRow));
    final lines = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byKey(BirthInfoRow.dividerKey),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(
      lines.map((box) => box.color),
      everyElement(context.tokens.colors.line),
    );
    final tag = tester.widget<HanjaTag>(find.byType(HanjaTag));
    expect(tag.variant, HanjaTagVariant.ganji);
    expect(tag.onTap, isNull);
    expect(tag.glyph, '未');
  });

  testWidgets('글자 배율 2.0에서도 칸 단위로 줄이 바뀌고 칸은 쪼개지지 않으며 줄이 바뀐 칸 앞에는 선이 없습니다', (
    tester,
  ) async {
    await tester.pumpWidget(inputApp(_scaled(_row(), 2)));
    final rects = [
      for (final key in BirthInfoRow.cellKeys) tester.getRect(find.byKey(key)),
    ];
    // 한 줄에 다 못 들어가 아래 줄로 내려간 칸이 있습니다.
    expect(rects[2].top, greaterThan(rects[0].top));
    // 칸 안 글자는 한 줄입니다(칸 높이가 알약 하나 높이 근처).
    for (final key in [BirthInfoRow.cellKeys[0], BirthInfoRow.cellKeys[2]]) {
      expect(
        tester.getRect(find.byKey(key)).height,
        lessThan(60),
        reason: '$key',
      );
    }
    // 칸은 화면 폭 안에 있습니다.
    for (final rect in rects) {
      expect(rect.right, lessThanOrEqualTo(360));
    }
    // 보이는 선은 같은 줄 이웃 사이에만 있습니다(줄이 바뀐 칸 앞의 선은 크기 0).
    final visible = tester
        .widgetList(find.byKey(BirthInfoRow.dividerKey))
        .map((w) => tester.getSize(find.byWidget(w)).width)
        .where((width) => width > 0)
        .length;
    final sameLinePairs = [
      rects[1].top < rects[0].bottom && rects[1].left > rects[0].left,
      rects[2].top < rects[1].bottom && rects[2].left > rects[1].left,
    ].where((joined) => joined).length;
    expect(visible, sameLinePairs);
  });

  testWidgets('시간 모름이면 시진 태그와 시간 대신 timeUnknownLabel 알약 하나입니다', (tester) async {
    await tester.pumpWidget(inputApp(_row(timeUnknown: true)));
    expect(find.byType(HanjaTag), findsNothing);
    expect(find.text('오후 2:30'), findsNothing);
    expect(find.text('모름'), findsOneWidget);
    expect(find.text('남성'), findsOneWidget);
  });

  testWidgets('스크린리더는 달력 종류와 날짜, 시진과 시간, 성별 순서로 하나로 읽습니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(_row()));
    expect(
      find.bySemanticsLabel('양력 1990.5.15, 미시 오후 2:30, 남성'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('loading 뼈는 폭 70% 글줄 하나입니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        SizedBox(width: 300, child: BirthInfoRow.skeleton(animated: false)),
      ),
    );
    final bone = tester.getSize(find.byType(FractionallySizedBox));
    expect(bone.width, 300);
    expect(
      tester.getSize(find.byType(SizedBox).last).width,
      moreOrLessEquals(210, epsilon: 0.5),
    );
  });
}
