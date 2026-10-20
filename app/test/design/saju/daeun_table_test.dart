import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

const _cell = OhaengCell(
  element: FiveElement.metal,
  hanja: '庚',
  size: OhaengCellSize.mini,
);

Widget _table({int? current = 3, double width = 360}) => SizedBox(
  width: width,
  child: DaeunTable(
    daeun: [
      for (var i = 0; i < 9; i++)
        DaeunPillar(
          age: 4 + i * 10,
          startYear: 1993 + i * 10,
          stem: _cell,
          branch: _cell,
          semanticLabel: '${4 + i * 10}세',
        ),
    ],
    seun: [
      for (var year = 2023; year < 2033; year++)
        SeunYear(
          year: year,
          stem: _cell,
          branch: _cell,
          semanticLabel: '$year년',
        ),
    ],
    currentIndex: current,
    thisYear: 2026,
    nowLabel: '지금',
    thisYearLabel: '올해',
    tableLabel: '대운 4세부터',
  ),
);

bool _tagVisible(WidgetTester tester, Key pillar) => tester
    .widget<Visibility>(
      find.descendant(
        of: find.byKey(pillar),
        matching: find.byType(Visibility),
      ),
    )
    .visible;

void main() {
  testWidgets('대운 기둥은 너비 52, 사이 4, 나이와 시작 연도', (tester) async {
    await tester.pumpWidget(inputApp(_table(current: 0)));
    final first = tester.getRect(find.byKey(DaeunTable.daeunKey(0)));
    final second = tester.getRect(find.byKey(DaeunTable.daeunKey(1)));
    expect(first.width, DaeunTable.pillarWidth);
    expect(second.left - first.right, DaeunTable.pillarGap);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1993'), findsOneWidget);
  });

  testWidgets('current: 지금 대운만 바탕·굵은 나이·지금 꼬리표', (tester) async {
    await tester.pumpWidget(inputApp(_table()));
    final colors = tester.element(find.byType(DaeunTable)).tokens.colors;
    expect(_tagVisible(tester, DaeunTable.daeunKey(3)), isTrue);
    expect(_tagVisible(tester, DaeunTable.daeunKey(2)), isFalse);
    final age = tester.widget<Text>(find.text('34'));
    expect(age.style?.color, colors.actionPrimary);
    expect(age.style?.fontWeight, FontWeight.w700);
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(DaeunTable.daeunKey(3)),
            matching: find.byKey(DaeunTable.highlightKey),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, colors.statusBg);
  });

  testWidgets('처음 열 때 지금 대운이 보이는 위치에서 움직임 없이 시작합니다', (tester) async {
    await tester.pumpWidget(inputApp(_table(current: 7, width: 200)));
    final viewport = tester.getRect(find.byKey(DaeunTable.daeunScrollKey));
    final current = tester.getRect(find.byKey(DaeunTable.daeunKey(7)));
    expect(current.left, greaterThanOrEqualTo(viewport.left));
    expect(current.right, lessThanOrEqualTo(viewport.right));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('thisYear: 세운 5열 2줄, 올해 칸만 꼬리표', (tester) async {
    await tester.pumpWidget(inputApp(_table()));
    final first = tester.getRect(find.byKey(DaeunTable.seunKey(2023)));
    final fifth = tester.getRect(find.byKey(DaeunTable.seunKey(2027)));
    final sixth = tester.getRect(find.byKey(DaeunTable.seunKey(2028)));
    expect(fifth.top, first.top);
    expect(sixth.top, greaterThan(first.bottom));
    expect(sixth.left, first.left);
    expect(_tagVisible(tester, DaeunTable.seunKey(2026)), isTrue);
    expect(_tagVisible(tester, DaeunTable.seunKey(2025)), isFalse);
    expect(find.byType(StatusTag), findsNWidgets(9 + 10));
  });

  testWidgets('표 이름과 지금·올해를 읽습니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(_table()));
    expect(find.bySemanticsLabel(RegExp('^대운 4세부터')), findsOneWidget);
    expect(find.bySemanticsLabel('34세, 지금'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년, 올해'), findsOneWidget);
    expect(find.bySemanticsLabel('2025년'), findsOneWidget);
    handle.dispose();
  });
}
