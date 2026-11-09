import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

BandTable _band({bool loading = false}) => BandTable(
  columns: const [
    BandColumn(header: '시주', empty: true),
    BandColumn(header: '일주', isDay: true),
    BandColumn(header: '월주'),
    BandColumn(header: '연주'),
  ],
  bandLabels: const {
    BandKind.hiddenStems: '지장간',
    BandKind.twelveStages: '12운성',
    BandKind.shinsal: '신살',
  },
  onBandTap: (_) {},
  meLabel: '나',
  emptyLabel: '없음',
  tableLabel: '만세력 표',
  loading: loading,
  animated: false,
);

Widget _table({
  String basis = '내 일간 庚(경금) 기준',
  String glyph = '庚',
  bool loading = false,
}) => SingleChildScrollView(
  child: SizedBox(
    width: 360,
    child: ManseTable(
      basis: basis,
      basisGlyph: glyph,
      table: _band(loading: loading),
    ),
  ),
);

TextSpan _basisSpan(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(ManseTable.basisKey)).textSpan! as TextSpan;

void main() {
  testWidgets('기준 줄은 간 한자만 font.family.hanja이고 caption.lg text.secondary입니다', (
    tester,
  ) async {
    await tester.pumpWidget(inputApp(_table()));
    final context = tester.element(find.byType(ManseTable));
    final tokens = context.tokens;
    final root = _basisSpan(tester);
    expect(root.style?.color, tokens.colors.textSecondary);
    expect(root.style?.fontSize, tokens.typography.captionLg.fontSize);
    final children = root.children!.cast<TextSpan>();
    expect(children.map((span) => span.text), ['내 일간 ', '庚', '(경금) 기준']);
    expect(
      children[1].style?.fontFamily,
      tokens.typography.hanjaPillar.fontFamily,
    );
    expect(children[0].style, isNull);
    expect(children[2].style, isNull);
  });

  testWidgets('basisGlyph가 문장에 없으면 한자 글꼴 없이 문장 그대로 그립니다', (tester) async {
    await tester.pumpWidget(inputApp(_table(glyph: '辛')));
    final root = _basisSpan(tester);
    expect(root.text, '내 일간 庚(경금) 기준');
    expect(root.children, isNull);
  });

  testWidgets('기준 줄과 표 사이는 space.12입니다', (tester) async {
    await tester.pumpWidget(inputApp(_table()));
    final basis = tester.getRect(find.byKey(ManseTable.basisKey));
    final table = tester.getRect(find.byType(BandTable));
    expect(table.top - basis.bottom, Space.s12);
  });

  testWidgets('loading: 기준 줄 뼈(폭 50%)와 band-table 뼈를 그립니다', (tester) async {
    await tester.pumpWidget(inputApp(_table(loading: true)));
    expect(find.byKey(ManseTable.basisKey), findsNothing);
    final bones = find.descendant(
      of: find.byType(ManseTable),
      matching: find.byType(SkeletonBone),
    );
    // 기준 줄 뼈 1 + 띠 칸 뼈 16((2 + 1 + 1) x 4열).
    expect(bones, findsNWidgets(17));
    final width = tester.getSize(bones.first).width;
    expect(width, moreOrLessEquals(180, epsilon: 0.5));
  });

  testWidgets('group semantics 묶음이고 글자 배율은 1.3에서 멈춥니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      inputApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _table(),
        ),
      ),
    );
    expect(find.bySemanticsLabel('만세력 표'), findsOneWidget);
    final context = tester.element(find.byKey(ManseTable.basisKey));
    expect(MediaQuery.textScalerOf(context).scale(10), moreOrLessEquals(13));
    // 기준 줄과 표는 한 묶음(group) 노드 안에 병합되지 않은 별도 자식입니다.
    // 묶음(group) 노드가 기준 줄 글자를 라벨로 갖고, 표 노드는 그 안의 병합되지 않은
    // 자식으로 남습니다(표 안 셀과 용어 칩이 표 노드 아래에서 따로 읽힘).
    final table = tester.getSemantics(find.bySemanticsLabel('만세력 표'));
    final group = table.parent!;
    expect(group.label, '내 일간 庚(경금) 기준');
    final children = <SemanticsNode>[];
    group.visitChildren((child) {
      children.add(child);
      return true;
    });
    expect(children.map((child) => child.label), contains('만세력 표'));
    expect(table.mergeAllDescendantsIntoThisNode, isFalse);
    handle.dispose();
  });
}
