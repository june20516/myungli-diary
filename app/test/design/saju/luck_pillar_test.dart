import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/tag_slot.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
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

  testWidgets('column 꼬리표: 바탕 아래 간격 4, 기둥보다 넓은 한 줄', (tester) async {
    await tester.pumpWidget(
      inputApp(Center(child: _column(current: true, tag: '지금 대운입니다 길게'))),
    );
    expect(tester.getSize(find.byType(TagSlot)).width, LuckPillar.columnWidth);
    final bg = tester.getRect(find.byKey(LuckPillar.highlightKey));
    final tag = tester.getRect(find.byType(StatusTag));
    expect(tag.top - bg.bottom, Space.s4);
    expect(tag.width, greaterThan(LuckPillar.columnWidth));
    expect(tag.width, lessThanOrEqualTo(LuckPillar.tagMaxWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('column 끝 기둥은 꼬리표를 표 안쪽으로 맞춤', (tester) async {
    for (final edge in [TagEdge.start, TagEdge.end]) {
      await tester.pumpWidget(
        inputApp(
          Align(
            alignment: edge == TagEdge.start
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: _column(current: true, tag: '지금 대운입니다 길게', edge: edge),
          ),
        ),
      );
      final pillar = tester.getRect(find.byType(TagSlot));
      final tag = tester.getRect(find.byType(StatusTag));
      if (edge == TagEdge.start) {
        expect(tag.left, pillar.left, reason: 'start');
      } else {
        expect(tag.right, pillar.right, reason: 'end');
      }
    }
  });

  testWidgets('column 지금이면 라벨 끝에 꼬리표 낱말을 붙여 읽음', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(Center(child: _column(current: true))));
    expect(find.bySemanticsLabel('10세, 비견, 갑오, 지금'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('십성 칩은 별도 포커스(button)이고 칸 글자는 그룹 라벨이 읽음', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(Center(child: _column())));
    expect(
      tester.getSemantics(find.text('비견')),
      isSemantics(label: '비견 뜻 보기', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('compact 용어 칩은 누를 수 있으면 button, 콜백 없으면 글자만', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await tester.pumpWidget(
      inputApp(
        Center(
          child: LuckPillar.compact(
            pillar: _ganji,
            tagLabel: '지금',
            kindLabel: '대운',
            period: '30~39세',
            tenGods: const [LuckLabel('比肩')],
            semanticLabel: '지금 대운',
            onKindTap: () => tapped++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('대운'));
    expect(tapped, 1);
    expect(find.bySemanticsLabel('대운 뜻 보기'), findsOneWidget);
    expect(find.bySemanticsLabel('比肩 뜻 보기'), findsNothing);
    handle.dispose();
  });

  testWidgets('칸 글자와 꼬리표는 낱개 노드로 읽히지 않고 칩 button은 하나씩', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(Center(child: _column(current: true))));
    for (final text in ['甲', '午', '지금', '10']) {
      expect(find.bySemanticsLabel(text), findsNothing, reason: 'column $text');
    }
    expect(find.bySemanticsLabel('비견 뜻 보기'), findsOneWidget);

    await tester.pumpWidget(
      inputApp(
        Center(
          child: LuckPillar.compact(
            pillar: _ganji,
            tagLabel: '지금',
            kindLabel: '대운',
            period: '30~39세',
            tenGods: [LuckLabel('비견', onTap: () {})],
            semanticLabel: '지금 대운 30~39세',
            onKindTap: () {},
          ),
        ),
      ),
    );
    for (final text in ['甲', '午', '지금', '30~39세']) {
      expect(
        find.bySemanticsLabel(text),
        findsNothing,
        reason: 'compact $text',
      );
    }
    expect(find.bySemanticsLabel('대운 뜻 보기'), findsOneWidget);
    expect(find.bySemanticsLabel('비견 뜻 보기'), findsOneWidget);
    handle.dispose();
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

  for (final scale in [1.3, 2.0]) {
    testWidgets('compact 글자 배율 $scale en: 기간 줄이 줄바꿈되고 넘치지 않음', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
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
      final style = tester
          .element(find.byKey(LuckPillar.periodKey))
          .tokens
          .typography
          .captionLg;
      // 배율은 1.3에서 멈춥니다.
      final oneLine = style.fontSize! * (style.height ?? 1) * 1.3;
      final root = tester.getRect(find.byType(LuckPillar));
      final period = tester.getRect(find.byKey(LuckPillar.periodKey));
      expect(period.height, greaterThan(oneLine * 1.5));
      expect(period.right, lessThanOrEqualTo(root.right));
      expect(root.width, lessThanOrEqualTo(220));
    });
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('column 글자 배율 $scale: 지금(굵게) 연도는 한 줄이고 기둥 폭을 넘지 않음', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: inputApp(
            Center(
              child: LuckPillar.column(
                pillar: _ganji,
                top: '2026',
                tenGod: LuckLabel('상관', onTap: () {}),
                semanticLabel: '2026년, 상관, 갑오',
                current: true,
                currentTag: '올해',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final year = find.text('2026');
      final style = tester.widget<Text>(year).style!;
      final oneLine = style.fontSize! * (style.height ?? 1) * 1.3;
      final rect = tester.getRect(year);
      final root = tester.getRect(find.byType(LuckPillar));
      expect(rect.height, lessThanOrEqualTo(oneLine + 0.5));
      expect(rect.left, greaterThanOrEqualTo(root.left));
      expect(rect.right, lessThanOrEqualTo(root.left + LuckPillar.columnWidth));
    });
  }

  testWidgets('loading 뼈: 칸 둘과 십성 칩 하나', (tester) async {
    await tester.pumpWidget(
      inputApp(Center(child: LuckPillar.skeleton(animated: false))),
    );
    final bones = tester.widgetList<SkeletonBone>(find.byType(SkeletonBone));
    expect(bones.map((b) => b.width), [40, 40, 36]);
  });
}
