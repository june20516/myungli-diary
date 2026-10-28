import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

const _cell = OhaengCell(
  element: FiveElement.metal,
  hanja: '庚',
  size: OhaengCellSize.mini,
);

Widget _table({
  int? current = 3,
  double width = 360,
  bool knownYears = true,
  void Function(String term)? onTerm,
  LuckLabel? Function(int index)? stage,
}) => SizedBox(
  width: width,
  child: DaeunTable(
    daeun: [
      for (var i = 0; i < 9; i++)
        DaeunPillar(
          age: 4 + i * 10,
          startYear: knownYears ? 1993 + i * 10 : null,
          stem: _cell,
          branch: _cell,
          ageSemanticLabel: '${4 + i * 10}세',
          semanticLabel: '庚 경 庚 경',
          yearSemanticLabel: knownYears ? '${1993 + i * 10}년' : null,
          stemLabel: onTerm == null ? null : _term('대운$i-천간', onTerm),
          branchLabel: onTerm == null ? null : _term('대운$i-지지', onTerm),
          stageLabel: stage?.call(i),
        ),
    ],
    seun: [
      for (var year = 2023; year < 2033; year++)
        SeunYear(
          year: year,
          stem: _cell,
          branch: _cell,
          yearSemanticLabel: '$year년',
          semanticLabel: '庚 경 庚 경',
          label: onTerm == null ? null : _term('세운$year', onTerm),
        ),
    ],
    currentIndex: current,
    thisYear: 2026,
    nowLabel: '지금',
    thisYearLabel: '올해',
    tableLabel: '대운 4세부터',
  ),
);

/// 누르면 [onTerm]에 [text]를 알리는 용어 라벨.
LuckLabel _term(String text, void Function(String term) onTerm) =>
    LuckLabel(text, onTap: () => onTerm(text));

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

  testWidgets('시작 연도를 모르면 그 줄을 비우고 나이는 그대로입니다', (tester) async {
    await tester.pumpWidget(inputApp(_table(current: null, knownYears: false)));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1993'), findsNothing);
    expect(
      tester.getSize(find.byKey(DaeunTable.daeunKey(0))).height,
      greaterThan(0),
    );
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

  testWidgets('십성 라벨: 대운은 천간 위·지지 아래, 세운은 천간 위이고 누르면 그 용어', (tester) async {
    final handle = tester.ensureSemantics();
    final tapped = <String>[];
    // 라벨만큼 키가 커지므로 화면처럼 스크롤 안에 둡니다.
    await tester.pumpWidget(
      inputApp(SingleChildScrollView(child: _table(onTerm: tapped.add))),
    );
    final cells = find.descendant(
      of: find.byKey(DaeunTable.daeunKey(3)),
      matching: find.byType(OhaengCell),
    );
    expect(
      tester.getRect(find.text('대운3-천간')).bottom,
      lessThanOrEqualTo(tester.getRect(cells.first).top),
    );
    expect(
      tester.getRect(find.text('대운3-지지')).top,
      greaterThanOrEqualTo(tester.getRect(cells.last).bottom),
    );
    final seunCell = find.descendant(
      of: find.byKey(DaeunTable.seunKey(2026)),
      matching: find.byType(OhaengCell),
    );
    expect(
      tester.getRect(find.text('세운2026')).bottom,
      lessThanOrEqualTo(tester.getRect(seunCell.first).top),
    );

    await tester.tap(find.text('대운3-천간'));
    await tester.tap(find.text('세운2026'));
    expect(tapped, ['대운3-천간', '세운2026']);
    // 라벨은 기둥 글과 따로 눌리는 자리로 읽힙니다.
    expect(find.bySemanticsLabel(RegExp('^대운3-지지')), findsOneWidget);
    expect(find.bySemanticsLabel('34세, 지금'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('12운성은 지지 십성 아래 2px이고, 두 줄 라벨이면 같은 줄 기둥이 그 높이를 따릅니다(V49)', (
    tester,
  ) async {
    await tester.pumpWidget(
      inputApp(
        SingleChildScrollView(
          child: _table(
            onTerm: (_) {},
            // 1번 기둥만 낱말 두 개라 두 줄, 2번 기둥은 이름이 없어 자리만 남습니다.
            stage: (i) => switch (i) {
              1 => const LuckLabel('제왕 건록'),
              2 => null,
              _ => const LuckLabel('장생'),
            },
          ),
        ),
      ),
    );
    Rect cellsOf(int index) => tester.getRect(
      find
          .descendant(
            of: find.byKey(DaeunTable.daeunKey(index)),
            matching: find.byType(OhaengCell),
          )
          .last,
    );
    expect(
      tester.getRect(find.text('대운0-지지')).bottom + 2,
      tester.getRect(find.text('장생').first).top,
    );
    final twoLines = tester.getRect(find.text('제왕 건록'));
    final oneLine = tester.getRect(find.text('장생').first);
    expect(twoLines.height, greaterThan(oneLine.height * 1.5));
    // 간지 칸과 시작 연도가 모든 기둥에서 나란합니다.
    expect(cellsOf(1).top, cellsOf(0).top);
    expect(cellsOf(2).top, cellsOf(0).top);
    expect(
      tester.getRect(find.text('1993')).top,
      tester.getRect(find.text('2003')).top,
    );
    expect(
      tester.getRect(find.text('2013')).top,
      tester.getRect(find.text('2003')).top,
    );
  });

  testWidgets('글자 크기 1.3배에서 낱말이 칸보다 넓으면 caption.sm으로 줄이고 말줄임이 없습니다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: inputApp(
          SingleChildScrollView(
            child: _table(stage: (i) => const LuckLabel('Prosperity')),
          ),
        ),
      ),
    );
    final typography = tester
        .element(find.byType(DaeunTable))
        .tokens
        .typography;
    final text = tester.widget<Text>(find.text('Prosperity').first);
    expect(text.style?.fontSize, typography.captionSm.fontSize);
    expect(text.overflow, TextOverflow.clip);
  });

  testWidgets('대운 기둥은 나이 → 천간 십성 → 간지 → 지지 십성 → 12운성 → 시작 연도 순서로 읽습니다', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      inputApp(
        SingleChildScrollView(
          child: _table(
            current: null,
            onTerm: (_) {},
            stage: (_) => const LuckLabel('장생'),
          ),
        ),
      ),
    );
    final pillar = tester.getSemantics(find.byKey(DaeunTable.daeunKey(0)));
    final labels = <String>[];
    void collect(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      node.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    collect(pillar);
    expect(labels, hasLength(6));
    expect(labels[0], '4세');
    expect(labels[1], startsWith('대운0-천간'));
    expect(labels[2], '庚 경 庚 경');
    expect(labels[3], startsWith('대운0-지지'));
    expect(labels[4], '장생');
    expect(labels[5], '1993년');
    handle.dispose();
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
