import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/tag_slot.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

const LuckGanji _ganji = LuckGanji(
  stemElement: FiveElement.wood,
  stemHanja: '甲',
  branchElement: FiveElement.fire,
  branchHanja: '午',
);

Widget _column({
  bool current = false,
  String? tag = '지금',
  TagEdge edge = TagEdge.none,
}) => LuckPillar.column(
  pillar: _ganji,
  top: '10',
  tenGod: LuckLabel('비견', onTap: () {}),
  semanticLabel: '10세, 비견, 갑오',
  current: current,
  currentTag: tag,
  tagEdge: edge,
);

Widget _compact({String period = '30~39세, 2030~2039년'}) => SizedBox(
  width: 320,
  child: LuckPillar.compact(
    pillar: _ganji,
    kind: LuckPillarKind.daeun,
    tagLabel: '지금',
    kindLabel: '대운',
    period: period,
    tenGods: [
      LuckLabel('비견', onTap: () {}),
      LuckLabel('식신', onTap: () {}),
    ],
    semanticLabel: '지금 대운',
  ),
);

void main() {
  testWidgets('ohaeng.cell small은 40 x 40', (tester) async {
    await tester.pumpWidget(
      inputApp(
        const Center(
          child: OhaengCell(
            element: FiveElement.wood,
            hanja: '甲',
            size: OhaengCellSize.small,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(OhaengCell)), const Size(40, 40));
  });

  testWidgets('column current: 바탕 highlightBg, 꼬리표는 바탕 밖 아래', (tester) async {
    await tester.pumpWidget(inputApp(Center(child: _column(current: true))));
    final highlight = find.byKey(LuckPillar.highlightKey);
    final box = tester.widget<ColoredBox>(
      find.descendant(of: highlight, matching: find.byType(ColoredBox)).first,
    );
    final context = tester.element(highlight);
    expect(box.color, context.tokens.colors.highlightBg);
    final bg = tester.getRect(highlight);
    final tag = tester.getRect(find.text('지금'));
    expect(tag.top, greaterThanOrEqualTo(bg.bottom));
    expect(find.byType(OhaengCell), findsNWidgets(2));
    expect(tester.getSize(find.byType(OhaengCell).first), const Size(40, 40));
  });

  testWidgets('column 지금이 아니면 바탕 없음, 꼬리표 자리는 높이만 남김', (tester) async {
    await tester.pumpWidget(inputApp(Center(child: _column())));
    expect(find.byKey(LuckPillar.highlightKey), findsNothing);
    expect(find.byKey(LuckPillar.tagKey), findsOneWidget);
    final slot = tester.getSize(find.byKey(LuckPillar.tagKey));
    expect(slot.width, LuckPillar.columnWidth);
    expect(slot.height, greaterThan(0));
  });

  testWidgets('column 꼬리표는 기둥보다 넓어도 한 줄로 이웃 쪽으로 넘침', (tester) async {
    await tester.pumpWidget(
      inputApp(Center(child: _column(current: true, tag: '지금 대운입니다 길게'))),
    );
    final tag = tester.getSize(find.byType(TagSlot));
    expect(tag.width, LuckPillar.columnWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact: 강조 바탕 없고 칸 둘이 세로', (tester) async {
    await tester.pumpWidget(inputApp(Center(child: _compact())));
    expect(find.byKey(LuckPillar.highlightKey), findsNothing);
    final cells = find.byType(OhaengCell);
    expect(cells, findsNWidgets(2));
    final a = tester.getRect(cells.at(0));
    final b = tester.getRect(cells.at(1));
    expect(a.left, b.left);
    expect(b.top - a.bottom, Space.s4);
    expect(find.text('지금'), findsOneWidget);
    expect(find.text('대운'), findsOneWidget);
  });

  testWidgets('compact 큰 글자 1.3 en에서 기간 줄이 줄바꿈되고 넘치지 않음', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: inputApp(
          Center(
            child: SizedBox(
              width: 220,
              child: _compact(
                period: 'Age 30 to 39, from 2030 to 2039 inclusive',
              ),
            ),
          ),
          locale: const Locale('en'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final period = tester.getSize(find.byKey(LuckPillar.periodKey));
    final style = tester
        .element(find.byKey(LuckPillar.periodKey))
        .tokens
        .typography
        .captionLg;
    final oneLine = style.fontSize! * (style.height ?? 1) * 1.3;
    expect(period.height, greaterThan(oneLine * 1.5));
  });

  testWidgets('loading 뼈: 칸 둘과 십성 칩 하나', (tester) async {
    await tester.pumpWidget(
      inputApp(Center(child: LuckPillar.skeleton(animated: false))),
    );
    final bones = tester.widgetList<SkeletonBone>(find.byType(SkeletonBone));
    expect(bones.map((b) => b.width), [40, 40, 36]);
  });
}
