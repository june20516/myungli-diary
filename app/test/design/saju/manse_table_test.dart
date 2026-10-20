import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

ManseColumn _column(
  String header, {
  bool empty = false,
  VoidCallback? onHiddenTenGod,
}) => empty
    ? ManseColumn(header: header)
    : ManseColumn(
        header: header,
        stem: const OhaengCell(
          element: FiveElement.metal,
          hanja: '庚',
          size: OhaengCellSize.mini,
        ),
        branch: const OhaengCell(
          element: FiveElement.earth,
          hanja: '辰',
          size: OhaengCellSize.mini,
        ),
        hiddenStems: [
          ManseHiddenStem(
            hanja: '乙',
            reading: '을',
            label: onHiddenTenGod == null
                ? null
                : GestureDetector(
                    onTap: onHiddenTenGod,
                    child: Text('$header-정재'),
                  ),
          ),
          const ManseHiddenStem(hanja: '癸', reading: '계'),
        ],
        twelveStage: Text('$header-운성'),
        shinsal: [Text('$header-신살1'), Text('$header-신살2')],
      );

Widget _table({
  bool hourUnknown = false,
  VoidCallback? onHeader,
  VoidCallback? onHiddenTenGod,
}) => ManseTable(
  hour: _column('시주', empty: hourUnknown),
  day: _column('일주', onHiddenTenGod: onHiddenTenGod),
  month: _column('월주'),
  year: _column('연주'),
  hiddenStemsHeader: GestureDetector(onTap: onHeader, child: const Text('지장간')),
  twelveStageHeader: const Text('12운성'),
  shinsalHeader: const Text('신살'),
  tableLabel: '만세력 표',
);

void main() {
  testWidgets('열 순서는 시·일·월·연, 줄 머리는 왼쪽 52 안', (tester) async {
    await tester.pumpWidget(inputApp(SizedBox(width: 360, child: _table())));
    final xs = [
      for (final header in ['시주', '일주', '월주', '연주'])
        tester.getCenter(find.text(header)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    final tableLeft = tester.getTopLeft(find.byType(Table)).dx;
    expect(
      tester.getTopRight(find.text('지장간')).dx - tableLeft,
      lessThanOrEqualTo(ManseTable.rowHeaderWidth),
    );
    expect(xs.first - tableLeft, greaterThan(ManseTable.rowHeaderWidth));
  });

  testWidgets('지장간은 한자 글꼴과 독음(text.secondary), 신살은 여러 줄', (tester) async {
    await tester.pumpWidget(inputApp(SizedBox(width: 360, child: _table())));
    final context = tester.element(find.byType(ManseTable));
    final rich = tester.widget<RichText>(
      find
          .byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == '乙 을',
          )
          .first,
    );
    TextSpan? spanOf(String text) {
      TextSpan? found;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == text) found = span;
        return found == null;
      });
      return found;
    }

    expect(
      spanOf('乙')?.style?.fontFamily,
      context.tokens.typography.hanjaPillar.fontFamily,
    );
    expect(spanOf(' 을')?.style?.color, context.tokens.colors.textSecondary);
    // 신살은 칸 안 여러 줄(위아래)입니다.
    expect(
      tester.getTopLeft(find.text('시주-신살2')).dy,
      greaterThan(tester.getTopLeft(find.text('시주-신살1')).dy),
    );
    expect(find.text('일주-운성'), findsOneWidget);
  });

  testWidgets('값 칸(12운성·신살)은 받은 위젯에 값 글자(type.body.ui text.primary)를 줍니다', (
    tester,
  ) async {
    await tester.pumpWidget(inputApp(SizedBox(width: 360, child: _table())));
    final context = tester.element(find.text('일주-운성'));
    final style = DefaultTextStyle.of(context).style;
    final tokens = context.tokens;
    expect(style.fontSize, tokens.typography.bodyUi.fontSize);
    expect(style.color, tokens.colors.textPrimary);
  });

  testWidgets('지장간 옆 용어 라벨을 누르면 그 콜백(지장간 십성 풀이)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      inputApp(
        SizedBox(width: 360, child: _table(onHiddenTenGod: () => taps++)),
      ),
    );
    await tester.tap(find.text('일주-정재'));
    expect(taps, 1);
    // 라벨이 없는 지장간은 한자·독음만입니다.
    expect(find.text('시주-정재'), findsNothing);
  });

  testWidgets('time-unknown: 시주 열은 빈 칸', (tester) async {
    await tester.pumpWidget(
      inputApp(SizedBox(width: 360, child: _table(hourUnknown: true))),
    );
    expect(find.text('시주-운성'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is OhaengCell && w.empty),
      findsNWidgets(2),
    );
  });

  testWidgets('줄 머리를 누르면 그 콜백(풀이)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      inputApp(SizedBox(width: 360, child: _table(onHeader: () => taps++))),
    );
    await tester.tap(find.text('지장간'));
    expect(taps, 1);
  });

  testWidgets('표 이름을 읽고 글자 크기는 1.3배에서 멈춥니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      inputApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(width: 360, child: _table()),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('^만세력 표')), findsOneWidget);
    final context = tester.element(find.text('일주-운성'));
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, 0.01));
    handle.dispose();
  });
}
