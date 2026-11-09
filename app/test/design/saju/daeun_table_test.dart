import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/frame/scroll_hint.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

const _ganji = LuckGanji(
  stemElement: FiveElement.metal,
  stemHanja: '庚',
  branchElement: FiveElement.water,
  branchHanja: '子',
);

LuckLabel _label(String text, [void Function(String)? onTap]) =>
    LuckLabel(text, onTap: onTap == null ? null : () => onTap(text));

Widget _table({
  int? current = 3,
  int thisYear = 2026,
  double width = 360,
  void Function(String term)? onTerm,
  LuckLabel? Function(int index)? stage,
  bool loading = false,
}) => SizedBox(
  width: width,
  child: SingleChildScrollView(
    child: loading
        ? const DaeunTable.loading(
            daeunTitle: '대운',
            daeunDescription: '10년마다 바뀌는 큰 흐름이에요.',
            seunTitle: '세운',
            seunDescription: '해마다 들어오는 기운이에요.',
            animated: false,
          )
        : DaeunTable(
            daeun: [
              for (var i = 0; i < 9; i++)
                DaeunPillar(
                  age: 4 + i * 10,
                  startYear: 1993 + i * 10,
                  pillar: _ganji,
                  ageSemanticLabel: '대운 ${4 + i * 10}세부터',
                  semanticLabel: '庚 경, 子 자',
                  yearSemanticLabel: '${1993 + i * 10}년',
                  stemLabel: _label('천간$i', onTerm),
                  branchLabel: _label('지지$i', onTerm),
                  stageLabel: stage?.call(i),
                ),
            ],
            seun: [
              for (var year = 2023; year < 2033; year++)
                SeunYear(
                  year: year,
                  pillar: _ganji,
                  yearSemanticLabel: '$year년',
                  semanticLabel: '庚 경, 子 자',
                  label: _label('세운$year', onTerm),
                ),
            ],
            currentIndex: current,
            thisYear: thisYear,
            nowLabel: '지금',
            thisYearLabel: '올해',
            daeunTitle: '대운',
            daeunDescription: '10년마다 바뀌는 큰 흐름이에요.',
            seunTitle: '세운',
            seunDescription: '해마다 들어오는 기운이에요.',
          ),
  ),
);

Finder _daeun(int index) => find.byKey(DaeunTable.daeunKey(index));
Finder _seun(int year) => find.byKey(DaeunTable.seunKey(year));

/// [cell]이 [row] 줄의 보이는 폭 안에 다 들어오는지.
bool _visibleIn(WidgetTester tester, Finder cell, Key row) {
  final viewport = tester.getRect(find.byKey(row));
  final rect = tester.getRect(cell);
  return rect.left >= viewport.left - 0.5 && rect.right <= viewport.right + 0.5;
}

void main() {
  testWidgets('섹션 머리 둘(설명 늘 보임)과 줄마다 흰 카드, scroll-hint', (tester) async {
    await tester.pumpWidget(inputApp(_table()));
    final headers = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .map((header) => (header.title, header.description))
        .toList();
    expect(headers, [('대운', '10년마다 바뀌는 큰 흐름이에요.'), ('세운', '해마다 들어오는 기운이에요.')]);
    expect(find.byType(ScrollHint), findsNWidgets(2));

    // 카드는 bg.sheet, radius.lg이고 위 space.12에서 줄이 시작합니다.
    final card = find
        .ancestor(
          of: find.byKey(DaeunTable.daeunScrollKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(Radii.lg),
          ),
        )
        .first;
    final context = tester.element(card);
    expect(
      (tester.widget<DecoratedBox>(card).decoration as BoxDecoration).color,
      context.tokens.colors.bgSheet,
    );
    expect(
      tester.getTopLeft(find.byKey(DaeunTable.daeunScrollKey)).dy -
          tester.getTopLeft(card).dy,
      Space.s12,
    );
  });

  testWidgets('기둥은 luck-pillar column, 너비 52, 사이 4, 줄 앞 여백 12', (tester) async {
    await tester.pumpWidget(inputApp(_table(current: null)));
    expect(tester.getSize(_daeun(0)).width, LuckPillar.columnWidth);
    expect(
      tester.getTopLeft(_daeun(1)).dx - tester.getTopRight(_daeun(0)).dx,
      DaeunTable.pillarGap,
    );
    expect(
      tester.getTopLeft(_daeun(0)).dx -
          tester.getTopLeft(find.byKey(DaeunTable.daeunScrollKey)).dx,
      DaeunTable.rowPaddingX,
    );
    final first = tester.widget<LuckPillar>(_daeun(0));
    expect(first.top, '4');
    expect(first.startYear, '1993');
    expect(first.twelveStage, isNull);
  });

  testWidgets('지금 대운, 올해 세운만 current이고 모든 기둥에 꼬리표 자리', (tester) async {
    await tester.pumpWidget(inputApp(_table()));
    final daeun = tester.widgetList<LuckPillar>(
      find.descendant(
        of: find.byKey(DaeunTable.daeunScrollKey),
        matching: find.byType(LuckPillar),
      ),
    );
    expect([for (final p in daeun) p.current].indexOf(true), 3);
    expect(daeun.where((p) => p.current), hasLength(1));
    expect(daeun.every((p) => p.currentTag == '지금'), isTrue);

    final seun = tester.widgetList<LuckPillar>(
      find.descendant(
        of: find.byKey(DaeunTable.seunScrollKey),
        matching: find.byType(LuckPillar),
      ),
    );
    expect(seun.where((p) => p.current).single.top, '2026');
    expect(seun.every((p) => p.currentTag == '올해'), isTrue);
  });

  testWidgets('세운 기둥은 연도, 천간 십성, 간지뿐(지지 십성, 12운성, 시작 연도 없음)', (tester) async {
    await tester.pumpWidget(inputApp(_table()));
    final seun = tester.widget<LuckPillar>(_seun(2024));
    expect(seun.top, '2024');
    expect(seun.tenGod?.text, '세운2024');
    expect(seun.branchTenGod, isNull);
    expect(seun.twelveStage, isNull);
    expect(seun.startYear, isNull);
  });

  testWidgets('처음 열 때 지금 대운과 올해 세운이 움직임 없이 줄 안에 보입니다', (tester) async {
    await tester.pumpWidget(inputApp(_table(current: 4, thisYear: 2027)));
    final before = tester.getTopLeft(_daeun(4));
    await tester.pumpAndSettle();
    // 처음 위치에서 움직이지 않습니다.
    expect(tester.getTopLeft(_daeun(4)), before);
    expect(_visibleIn(tester, _daeun(4), DaeunTable.daeunScrollKey), isTrue);
    expect(_visibleIn(tester, _daeun(0), DaeunTable.daeunScrollKey), isFalse);
    expect(_visibleIn(tester, _seun(2027), DaeunTable.seunScrollKey), isTrue);
    // 지금 칸은 줄 가운데 쪽입니다(양쪽에 더 있음).
    final row = tester.getRect(find.byKey(DaeunTable.daeunScrollKey));
    final cell = tester.getRect(_daeun(4));
    expect(
      (cell.center.dx - row.center.dx).abs(),
      lessThan(LuckPillar.columnWidth),
    );
  });

  testWidgets('지금 대운이 없으면 처음부터', (tester) async {
    await tester.pumpWidget(inputApp(_table(current: null, thisYear: 1990)));
    expect(_visibleIn(tester, _daeun(0), DaeunTable.daeunScrollKey), isTrue);
    expect(_visibleIn(tester, _seun(2023), DaeunTable.seunScrollKey), isTrue);
  });

  testWidgets('두 줄 라벨이 하나 있으면 같은 줄 기둥의 간지 칸이 가로로 나란합니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        _table(
          current: null,
          stage: (i) =>
              i == 1 ? const LuckLabel('아주 긴 운성') : const LuckLabel('양'),
        ),
      ),
    );
    final first = tester.widget<LuckPillar>(_daeun(0));
    expect(first.rowHeights, isNotNull);
    final stems = [
      for (var i = 0; i < 3; i++)
        tester
            .getTopLeft(
              find
                  .descendant(of: _daeun(i), matching: find.byType(OhaengCell))
                  .first,
            )
            .dy,
    ];
    expect(stems.toSet(), hasLength(1));
    final years = [
      for (var i = 0; i < 3; i++)
        tester.getTopLeft(find.text('${1993 + i * 10}')).dy,
    ];
    expect(years.toSet(), hasLength(1));
  });

  testWidgets('십성 칩을 누르면 그 라벨의 onTap', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(inputApp(_table(onTerm: tapped.add)));
    await tester.tap(find.text('천간3'));
    await tester.tap(find.text('세운2026'));
    expect(tapped, ['천간3', '세운2026']);
  });

  testWidgets('스크린리더: 줄마다 목록, 기둥 그룹 라벨에 누를 수 있는 칩 낱말은 없음', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      inputApp(_table(onTerm: (_) {}, stage: (_) => const LuckLabel('양'))),
    );
    final list = tester.getSemantics(
      find
          .descendant(
            of: find.byKey(DaeunTable.daeunScrollKey),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.role == SemanticsRole.list,
            ),
          )
          .first,
    );
    expect(list.label, '대운');
    expect(
      find.bySemanticsLabel('대운 34세부터, 庚 경, 子 자, 양, 2023년, 지금'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('2026년, 庚 경, 子 자, 올해'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('글자 크기: 기둥 줄만 1.3배에서 멈추고 섹션 머리는 기기 배율을 따릅니다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: inputApp(_table()),
      ),
    );
    final pillar = MediaQuery.textScalerOf(tester.element(_daeun(0)));
    expect(pillar.scale(10), closeTo(13, 0.01));
    final header = MediaQuery.textScalerOf(
      tester.element(find.text('10년마다 바뀌는 큰 흐름이에요.')),
    );
    expect(header.scale(10), closeTo(20, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading: 섹션 머리는 그대로, 카드마다 보이는 수만큼 기둥 뼈', (tester) async {
    await tester.pumpWidget(inputApp(_table(loading: true)));
    expect(find.byType(SectionHeader), findsNWidgets(2));
    expect(find.byType(LuckPillar), findsNothing);
    expect(find.byType(StatusTag), findsNothing);
    // 360 - 24 = 336, (336 + 4) / 56 = 6개씩 두 줄.
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(DaeunTable.skeletonPillarKey(i)), findsNWidgets(2));
    }
    expect(find.byKey(DaeunTable.skeletonPillarKey(6)), findsNothing);
  });
}
