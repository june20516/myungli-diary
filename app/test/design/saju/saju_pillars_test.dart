import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/tag_me.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

SajuPillarColumn _column(
  String header, {
  bool empty = false,
  String stem = '庚',
  String branch = '辰',
}) => SajuPillarColumn(
  header: header,
  semanticLabel: '$header 라벨',
  stem: empty
      ? null
      : OhaengCell(element: FiveElement.metal, hanja: stem, reading: '경'),
  branch: empty
      ? null
      : OhaengCell(element: FiveElement.earth, hanja: branch, reading: '진'),
  stemLabel: Text('$header-위'),
  branchLabel: Text('$header-아래'),
);

Widget _pillars({bool hourUnknown = false}) => SajuPillars(
  hour: _column('시주', empty: hourUnknown),
  day: _column('일주'),
  month: _column('월주'),
  year: _column('연주'),
  meLabel: '나',
  tableLabel: '원국표',
);

Widget _scaled(Widget child, double scale) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
  child: child,
);

void main() {
  group('ohaeng.cell', () {
    testWidgets('오행별 바탕·글자, pillar 높이 66과 아래 독음', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const OhaengCell(element: FiveElement.wood, hanja: '甲', reading: '갑'),
        ),
      );
      final colors = tester.element(find.byType(OhaengCell)).tokens.colors;
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(OhaengCell),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration! as BoxDecoration).color, colors.ohaengWoodBg);
      expect(
        tester.widget<Text>(find.text('甲')).style?.color,
        colors.ohaengWoodFg,
      );
      expect(tester.getSize(find.byType(Container)).height, 66);
      expect(find.text('갑'), findsOneWidget);
    });

    testWidgets('mini는 30 × 30이고 독음을 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const Center(
            child: OhaengCell(
              element: FiveElement.water,
              hanja: '子',
              reading: '자',
              size: OhaengCellSize.mini,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(OhaengCell)), const Size(30, 30));
      expect(find.text('자'), findsNothing);
    });

    testWidgets('글자 크기 2배여도 칸은 1.3배에서 멈춥니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          _scaled(
            const Center(
              child: OhaengCell(
                element: FiveElement.fire,
                hanja: '丙',
                size: OhaengCellSize.mini,
              ),
            ),
            2,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(OhaengCell)).width,
        closeTo(30 * 1.3, 0.01),
      );
    });

    testWidgets('빈 칸은 글자 없이 점선 테두리입니다', (tester) async {
      await tester.pumpWidget(inputApp(const OhaengCell.empty()));
      expect(
        find.descendant(
          of: find.byType(OhaengCell),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(OhaengCell),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });

  group('saju-pillars', () {
    testWidgets('열 순서는 시·일·월·연이고 천간 위·지지 아래에 라벨', (tester) async {
      await tester.pumpWidget(inputApp(_pillars()));
      final xs = [
        for (final header in ['시주', '일주', '월주', '연주'])
          tester.getCenter(find.text(header)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      final cellTop = tester.getTopLeft(find.byType(OhaengCell).first).dy;
      expect(tester.getBottomLeft(find.text('시주-위')).dy, lessThan(cellTop));
      final cellBottom = tester.getBottomLeft(find.byType(OhaengCell).at(1)).dy;
      expect(tester.getTopLeft(find.text('시주-아래')).dy, greaterThan(cellBottom));
    });

    testWidgets('일간만 테두리와 나 꼬리표, 꼬리표는 칸 위로 삐져나옵니다', (tester) async {
      await tester.pumpWidget(inputApp(_pillars()));
      expect(find.byKey(SajuPillars.dayMasterKey), findsOneWidget);
      expect(find.byType(TagMe), findsOneWidget);
      final colors = tester.element(find.byType(SajuPillars)).tokens.colors;
      final border =
          tester
                  .widget<DecoratedBox>(find.byKey(SajuPillars.dayMasterKey))
                  .decoration
              as BoxDecoration;
      expect(border.border!.top.color, colors.actionPrimary);
      expect(border.border!.top.width, 2);
      expect(
        tester.getTopLeft(find.byKey(SajuPillars.meTagKey)).dy,
        lessThan(tester.getTopLeft(find.byKey(SajuPillars.dayMasterKey)).dy),
      );
      // 일주 열 안에 있습니다.
      expect(
        tester.getCenter(find.byKey(SajuPillars.dayMasterKey)).dx,
        greaterThan(tester.getCenter(find.text('시주')).dx),
      );
    });

    testWidgets('time-unknown: 시주는 점선 빈 칸 둘', (tester) async {
      await tester.pumpWidget(inputApp(_pillars(hourUnknown: true)));
      expect(
        find.byWidgetPredicate((w) => w is OhaengCell && w.empty),
        findsNWidgets(2),
      );
    });

    testWidgets('표 이름과 열마다 라벨을 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_pillars()));
      expect(find.bySemanticsLabel('원국표'), findsOneWidget);
      for (final header in ['시주', '일주', '월주', '연주']) {
        expect(find.bySemanticsLabel(RegExp('^$header 라벨')), findsOneWidget);
      }
      handle.dispose();
    });

    testWidgets('글자 크기 2배여도 머리 글자는 1.3배에서 멈춥니다', (tester) async {
      await tester.pumpWidget(inputApp(_scaled(_pillars(), 2)));
      final context = tester.element(find.text('시주'));
      expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, 0.01));
    });
  });
}
