import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/stem_chip.dart';
import 'package:myungli_diary/design/elements/tag_me.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

BandColumn _column(
  String header, {
  bool isDay = false,
  bool empty = false,
  bool withShinsal = true,
  List<String>? shinsal,
  List<String>? shinsalTaps,
  VoidCallback? onStage,
}) => BandColumn(
  header: header,
  isDay: isDay,
  empty: empty,
  hiddenStems: [
    BandHiddenStem(
      element: FiveElement.wood,
      hanja: '乙',
      semanticLabel: '乙 을',
      tenGod: LuckLabel('$header-정재', onTap: () {}),
    ),
    const BandHiddenStem(
      element: FiveElement.water,
      hanja: '癸',
      semanticLabel: '癸 계',
    ),
  ],
  twelveStage: LuckLabel('$header-운성', onTap: onStage),
  shinsal: [
    if (withShinsal)
      for (final name in shinsal ?? ['$header-신살'])
        LuckLabel(name, onTap: () => shinsalTaps?.add(name)),
  ],
);

BandTable _table({
  bool hourUnknown = false,
  bool loading = false,
  List<BandKind>? taps,
  VoidCallback? onStage,
  bool shinsalOnDay = true,
  List<String>? dayShinsal,
  List<String>? shinsalTaps,
}) => BandTable(
  columns: [
    _column('시주', empty: hourUnknown),
    _column(
      '일주',
      isDay: true,
      withShinsal: shinsalOnDay,
      shinsal: dayShinsal,
      shinsalTaps: shinsalTaps,
    ),
    _column('월주', onStage: onStage),
    _column('연주'),
  ],
  bandLabels: const {
    BandKind.hiddenStems: '지장간',
    BandKind.twelveStages: '12운성',
    BandKind.shinsal: '신살',
  },
  onBandTap: (kind) => taps?.add(kind),
  meLabel: '나',
  emptyLabel: '없음',
  tableLabel: '만세력 표',
  loading: loading,
  animated: false,
);

Widget _wrap(Widget table, {double width = 360}) => SingleChildScrollView(
  child: SizedBox(width: width, child: table),
);

void main() {
  testWidgets('열 순서는 시·일·월·연이고 네 열이 같은 폭입니다', (tester) async {
    await tester.pumpWidget(inputApp(_wrap(_table())));
    final xs = [
      for (final header in ['시주', '일주', '월주', '연주'])
        tester.getCenter(find.text(header)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    // 칸 첫 지장간 칩의 가운데는 네 열이 같은 간격입니다(같은 폭).
    final chips = [
      for (final index in [0, 2, 4, 6])
        tester.getCenter(find.byType(StemChip).at(index)).dx,
    ];
    final gaps = [
      chips[1] - chips[0],
      chips[2] - chips[1],
      chips[3] - chips[2],
    ];
    expect(gaps[1], moreOrLessEquals(gaps[0], epsilon: 1));
    expect(gaps[2], moreOrLessEquals(gaps[0], epsilon: 1));
  });

  testWidgets('일주 열은 highlight.bg 바탕이 열 머리부터 마지막 띠 끝까지 깔립니다', (tester) async {
    await tester.pumpWidget(inputApp(_wrap(_table())));
    final context = tester.element(find.byType(BandTable));
    final day = find.byKey(BandTable.dayColumnKey);
    final bg = tester.widget<ColoredBox>(
      find.descendant(of: day, matching: find.byType(ColoredBox)).first,
    );
    expect(bg.color, context.tokens.colors.highlightBg);
    final dayRect = tester.getRect(day);
    final headerTop = tester.getTopLeft(find.text('일주')).dy;
    final lastBottom = tester.getBottomLeft(find.text('일주-신살')).dy;
    expect(dayRect.top, lessThanOrEqualTo(headerTop));
    expect(dayRect.bottom, greaterThanOrEqualTo(lastBottom));
    // 열 머리: action.primary 700 + tag.me.
    final header = tester.widget<Text>(find.text('일주'));
    expect(header.style?.color, context.tokens.colors.actionPrimary);
    expect(header.style?.fontWeight, FontWeight.w700);
    expect(find.byType(TagMe), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(TagMe)).dx,
      greaterThan(tester.getTopRight(find.text('일주')).dx),
    );
    // 다른 열은 보통 머리입니다.
    final other = tester.widget<Text>(find.text('월주'));
    expect(other.style?.color, context.tokens.colors.textSecondary);
  });

  testWidgets('열 구분선(0.5px line)은 모든 띠를 관통하고 띠 머리줄이 흰 바탕으로 가립니다', (
    tester,
  ) async {
    await tester.pumpWidget(inputApp(_wrap(_table())));
    final context = tester.element(find.byType(BandTable));
    final line = context.tokens.colors.line;
    // 바탕 층 열 셋(일주, 월주, 연주)은 왼쪽 0.5px line 테두리를 가집니다.
    final columns = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(Positioned),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((box) => (box.decoration as BoxDecoration).border != null)
        .toList();
    expect(columns, hasLength(3));
    for (final box in columns) {
      final left = ((box.decoration as BoxDecoration).border! as Border).left;
      expect(left.color, line);
      expect(left.width, BorderTokens.hairline);
    }
    // 층은 마지막 띠 끝까지 이어집니다.
    final grid = tester.getRect(find.byType(Positioned).first);
    final lastBand = tester.getRect(find.text('연주-신살'));
    expect(grid.bottom, greaterThan(lastBand.bottom));
    // 띠 머리줄 셋: 네 열에 걸친 흰 바탕, 위아래 0.5px line.
    final headers = find.byKey(BandTable.bandHeaderKey);
    expect(headers, findsNWidgets(3));
    final tableRect = tester.getRect(find.byType(BandTable));
    for (final element in headers.evaluate()) {
      final box = element.widget as DecoratedBox;
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, context.tokens.colors.bgSheet);
      final border = decoration.border! as Border;
      expect(border.top.width, BorderTokens.hairline);
      expect(border.bottom.color, line);
      final rect = tester.getRect(find.byWidget(box));
      expect(rect.width, tableRect.width - Space.s12 * 2);
    }
  });

  testWidgets('띠 이름은 가운데 용어 칩이고 누르면 그 띠로 onBandTap', (tester) async {
    final taps = <BandKind>[];
    await tester.pumpWidget(inputApp(_wrap(_table(taps: taps))));
    await tester.tap(find.widgetWithText(TermToken, '12운성'));
    await tester.tap(find.widgetWithText(TermToken, '신살'));
    expect(taps, [BandKind.twelveStages, BandKind.shinsal]);
    final center = tester.getCenter(find.widgetWithText(TermToken, '지장간')).dx;
    final table = tester.getRect(find.byType(BandTable));
    expect(center, moreOrLessEquals(table.center.dx, epsilon: 1));
  });

  testWidgets('지장간은 오행 칩 + 십성 한 줄을 세로로 쌓고, 칩은 읽지 않고 한자와 독음을 읽습니다', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(_wrap(_table())));
    final first = tester.getRect(find.byType(StemChip).first);
    final second = tester.getRect(find.byType(StemChip).at(1));
    expect(first.width, StemChip.side);
    expect(second.top, greaterThanOrEqualTo(first.bottom + Space.s4));
    final label = tester.getRect(find.text('시주-정재'));
    expect(label.left, greaterThanOrEqualTo(first.right + Space.s4));
    expect(find.bySemanticsLabel('乙 을'), findsWidgets);
    handle.dispose();
  });

  testWidgets('값이 없는 칸은 12×1 가로선이고 스크린리더는 없음을 읽습니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(_wrap(_table(shinsalOnDay: false))));
    final line = find.byKey(BandTable.emptyLineKey);
    expect(line, findsOneWidget);
    final size = tester.getSize(line);
    expect(size.width, 12);
    expect(size.height, 1);
    final context = tester.element(find.byType(BandTable));
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(of: line, matching: find.byType(ColoredBox)),
          )
          .color,
      context.tokens.colors.textSecondary,
    );
    expect(find.bySemanticsLabel('신살, 일주, 없음'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('빈 칸 선은 칸 위 space.8 아래 한 줄 상자 가운데, 이웃 칸 첫 줄과 같은 높이입니다(V101)', (
    tester,
  ) async {
    await tester.pumpWidget(inputApp(_wrap(_table(shinsalOnDay: false))));
    final box = tester.getRect(find.byKey(BandTable.emptyBoxKey));
    final line = tester.getRect(find.byKey(BandTable.emptyLineKey));
    expect(line.center.dy, closeTo(box.center.dy, 0.01));
    // 이웃 칸(월주) 신살 칩 첫 줄과 같은 높이에서 시작하고 같은 가운데입니다.
    final neighbor = tester.getRect(find.text('월주-신살'));
    expect(box.top, closeTo(neighbor.top, 0.01));
    expect(line.center.dy, closeTo(neighbor.center.dy, 0.5));
    final context = tester.element(find.byKey(BandTable.emptyBoxKey));
    expect(
      box.height,
      closeTo(
        BandTable.emptyBoxHeightOf(
          BandKind.shinsal,
          context.tokens.typography.captionMd,
          MediaQuery.textScalerOf(context),
        ),
        0.01,
      ),
    );
  });

  testWidgets('시간 모름 지장간 빈 칸 상자는 stem.chip 22, 선은 이웃 칩 가운데 높이입니다', (
    tester,
  ) async {
    // 이웃 칸 십성 라벨이 한 줄인 폭(칩 줄 높이 = 칩 22)에서 잽니다.
    await tester.pumpWidget(
      inputApp(_wrap(_table(hourUnknown: true), width: 600)),
    );
    final boxes = find.byKey(BandTable.emptyBoxKey);
    final stemBox = tester.getRect(boxes.first);
    expect(stemBox.height, StemChip.side);
    expect(BandTable.emptyBoxStemHeight, StemChip.side);
    final neighborChip = tester.getRect(find.byType(StemChip).first);
    expect(stemBox.top, closeTo(neighborChip.top, 0.01));
    final line = tester.getRect(find.byKey(BandTable.emptyLineKey).first);
    expect(line.center.dy, closeTo(neighborChip.center.dy, 0.01));
  });

  testWidgets('시간 모름이면 시주 열은 머리만 두고 모든 띠가 빈 칸입니다', (tester) async {
    await tester.pumpWidget(inputApp(_wrap(_table(hourUnknown: true))));
    expect(find.text('시주'), findsOneWidget);
    expect(find.text('시주-정재'), findsNothing);
    expect(find.byKey(BandTable.emptyLineKey), findsNWidgets(3));
  });

  testWidgets('표 role과 이름을 가집니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(_wrap(_table())));
    expect(find.bySemanticsLabel('만세력 표'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('loading: 머리, 띠 머리줄, 구분선, 일주 바탕은 바로, 칸은 칩 모양 뼈', (tester) async {
    await tester.pumpWidget(inputApp(_wrap(_table(loading: true))));
    expect(find.text('시주'), findsOneWidget);
    expect(find.byKey(BandTable.bandHeaderKey), findsNWidgets(3));
    expect(find.byKey(BandTable.dayColumnKey), findsOneWidget);
    // 지장간 칸마다 칩 + 라벨 뼈 둘, 12운성과 신살은 라벨 뼈 하나: (2 + 1 + 1) × 4.
    expect(find.byType(SkeletonBone), findsNWidgets(16));
    expect(find.byType(StemChip), findsNothing);
  });

  testWidgets('신살 칸은 다섯 넘게도 모두 space.4 간격으로 쌓고 띠는 가장 높은 칸만큼 늘어납니다(V121)', (
    tester,
  ) async {
    const names = ['월덕귀인', '괴강', '십악대패', '화개', '과숙', '암록'];
    await tester.pumpWidget(
      inputApp(_wrap(_table(dayShinsal: names), width: 320)),
    );
    expect(tester.takeException(), isNull);
    final rects = [
      for (final name in names)
        tester.getRect(find.widgetWithText(TermToken, name)),
    ];
    for (var i = 1; i < rects.length; i++) {
      // 받은 순서 그대로 위에서 아래로, 칩 사이는 space.4입니다.
      expect(
        rects[i].top - rects[i - 1].bottom,
        moreOrLessEquals(BandTable.shinsalGap, epsilon: 0.01),
      );
    }
    // 띠가 가장 높은 칸만큼 늘어나 마지막 칩이 표 안에 있고, 이웃 칸은 그 띠 위쪽에 놓입니다.
    final table = tester.getRect(find.byType(BandTable));
    expect(table.bottom, greaterThanOrEqualTo(rects.last.bottom));
    final neighbor = tester.getRect(find.widgetWithText(TermToken, '월주-신살'));
    expect(neighbor.top, moreOrLessEquals(rects.first.top, epsilon: 0.01));
  });

  testWidgets('쌓인 신살 칩은 어느 칩을 눌러도 그 칩이 받습니다(이웃 칩의 넓힌 눌림이 가로채지 않음)', (
    tester,
  ) async {
    const names = ['월덕귀인', '괴강', '십악대패', '화개', '과숙'];
    final taps = <String>[];
    await tester.pumpWidget(
      inputApp(_wrap(_table(dayShinsal: names, shinsalTaps: taps))),
    );
    for (final name in names) {
      final chip = find.widgetWithText(TermToken, name);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      final rect = tester.getRect(chip);
      // 칩 가운데와 위아래 가장자리 안쪽.
      for (final dy in [rect.top + 1, rect.center.dy, rect.bottom - 1]) {
        await tester.tapAt(Offset(rect.center.dx, dy));
        await tester.pumpAndSettle();
      }
    }
    expect(taps, [
      for (final name in names) ...[name, name, name],
    ]);

    // 칩 사이 틈(space.4)은 아무 칩도 덮지 않아 넓힌 판정으로 넘어가고, 하나만 받습니다(아래
    // 칩, Column은 뒤 자식부터 판정). 같은 틈을 두 칩이 함께 받거나 아무도 받지 않으면 안 됩니다.
    taps.clear();
    for (var i = 0; i < names.length - 1; i++) {
      final upper = tester.getRect(find.widgetWithText(TermToken, names[i]));
      final lower = tester.getRect(
        find.widgetWithText(TermToken, names[i + 1]),
      );
      await tester.tapAt(
        Offset(lower.center.dx, (upper.bottom + lower.top) / 2),
      );
      await tester.pumpAndSettle();
    }
    expect(taps, names.skip(1).toList());
  });

  testWidgets('글자 배율 2.0은 1.3에서 멈추고 넘치지 않습니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _wrap(_table()),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final context = tester.element(find.text('월주'));
    expect(MediaQuery.textScalerOf(context).scale(10), moreOrLessEquals(13));
  });
}
