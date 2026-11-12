import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/today/time_band.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

const double _width = 312;

/// 07:30부터 보이는 띠(낮 일곱 칸 다음 밤 다섯 칸). 낮 칩을 열어 낮 신시는 연 칩 고리, 밤 축시는
/// 다른 칩 고리입니다.
List<TimeBandCell> _fromDayStart() => [
  for (final (index, label) in '진사오미신유술'.split('').indexed)
    TimeBandCell(
      label: label,
      period: AppTimeOfDay.day,
      pick: index == 4 ? TimeBandPick.opened : null,
    ),
  for (final (index, label) in '해자축인묘'.split('').indexed)
    TimeBandCell(
      label: label,
      period: AppTimeOfDay.night,
      pick: index == 2 ? TimeBandPick.other : null,
    ),
];

/// 07:30 전에 보이는 띠(밤 다섯 칸 다음 낮 일곱 칸).
List<TimeBandCell> _beforeDayStart() => [
  ..._fromDayStart().skip(7),
  ..._fromDayStart().take(7),
];

TimeBand _band({
  List<TimeBandCell>? cells,
  double nowFraction = 0.5,
  bool hanjaLabels = false,
}) => TimeBand(
  cells: cells ?? _fromDayStart(),
  dayHead: '낮',
  nightHead: '밤',
  nowFraction: nowFraction,
  nowLabel: '지금 19:30',
  startTick: const TimeBandTick(time: '07:30'),
  boundaryTick: const TimeBandTick(time: '21:30'),
  endTick: const TimeBandTick(time: '07:30', dayWord: '내일'),
  hanjaLabels: hanjaLabels,
);

Widget _app(TimeBand band, {Brightness brightness = Brightness.light}) =>
    inputApp(
      Center(
        child: SizedBox(width: _width, child: band),
      ),
      brightness: brightness,
    );

void main() {
  testWidgets('칸은 12개, 사이 2, 높이 30이고 낮은 토, 밤은 수 칸 색입니다', (tester) async {
    await tester.pumpWidget(_app(_band()));
    final colors = tester.element(find.byType(TimeBand)).tokens.colors;
    final first = tester.getRect(find.byKey(TimeBand.cellKey(0)));
    final second = tester.getRect(find.byKey(TimeBand.cellKey(1)));
    expect(first.height, TimeBand.cellHeight);
    expect(second.left - first.right, moreOrLessEquals(TimeBand.cellGap));
    final last = tester.getRect(find.byKey(TimeBand.cellKey(11)));
    expect(last.right - first.left, moreOrLessEquals(_width));
    BoxDecoration fillOf(int index) =>
        tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(TimeBand.cellKey(index)),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .last
                .decoration
            as BoxDecoration;
    expect(fillOf(0).color, colors.ohaengEarthBg);
    expect(fillOf(11).color, colors.ohaengWaterBg);
    expect(
      tester.widget<Text>(find.text('진')).style!.color,
      colors.ohaengEarthFg,
    );
    expect(
      tester.widget<Text>(find.text('해')).style!.color,
      colors.ohaengWaterFg,
    );
  });

  testWidgets('연 칩 시진은 2px primary 고리와 글자 700, 다른 칩 시진은 1px 고리(V124)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_band()));
    final colors = tester.element(find.byType(TimeBand)).tokens.colors;
    BoxDecoration ringOf(int index) =>
        tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(TimeBand.cellKey(index)),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .first
                .decoration
            as BoxDecoration;
    final opened = ringOf(4);
    final openedBorder = opened.border! as Border;
    expect(openedBorder.top.color, colors.actionPrimary);
    expect(openedBorder.top.width, 2);
    expect(opened.color, colors.bgSheet);
    // 칸 9(밤 축시)는 다른 칩이 고른 시진입니다.
    final other = ringOf(9);
    final otherBorder = other.border! as Border;
    expect(otherBorder.top.color, colors.textSecondary);
    expect(otherBorder.top.width, 1);
    expect(other.color, colors.bgSheet);
    // 고리와 틈은 칸 안쪽이라(placement inside) 칸 크기가 같고 칸 사이 2를 넘지 않습니다.
    final plain = tester.getRect(find.byKey(TimeBand.cellKey(3)));
    final openedRect = tester.getRect(find.byKey(TimeBand.cellKey(4)));
    final next = tester.getRect(find.byKey(TimeBand.cellKey(5)));
    for (final size in [
      openedRect.size,
      tester.getSize(find.byKey(TimeBand.cellKey(9))),
    ]) {
      expect(size.width, moreOrLessEquals(plain.width));
      expect(size.height, moreOrLessEquals(plain.height));
    }
    expect(openedRect.left - plain.right, moreOrLessEquals(TimeBand.cellGap));
    expect(next.left - openedRect.right, moreOrLessEquals(TimeBand.cellGap));
    // 칸 색은 고리와 틈만큼 안쪽에서 시작합니다.
    final inset = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byKey(TimeBand.cellKey(9)),
            matching: find.byType(Padding),
          ),
        )
        .first;
    expect(inset.padding, const EdgeInsets.all(1 + 2));
    expect(
      tester.widget<Text>(find.text('신')).style!.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('사')).style!.fontWeight,
      isNot(FontWeight.w700),
    );
    // 다른 칩 시진 글자는 칸 글자 그대로(inherit)입니다.
    expect(
      tester.widget<Text>(find.text('축')).style!.fontWeight,
      tester.widget<Text>(find.text('묘')).style!.fontWeight,
    );
  });

  testWidgets('머리는 덩어리 시작에 해와 달 16 + 낱말이고, 07:30 전에는 밤이 앞입니다', (tester) async {
    await tester.pumpWidget(_app(_band(cells: _beforeDayStart())));
    final colors = tester.element(find.byType(TimeBand)).tokens.colors;
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons.map((icon) => icon.icon), [
      AppTimeOfDay.night.glyph,
      AppTimeOfDay.day.glyph,
    ]);
    expect(icons.map((icon) => icon.size), [16, 16]);
    expect(icons.map((icon) => icon.color), [colors.timeNight, colors.timeDay]);
    expect(
      tester.getTopLeft(find.text('밤')).dx,
      lessThan(tester.getTopLeft(find.text('낮')).dx),
    );
    // 둘째 머리는 둘째 덩어리(낮 첫 칸) 시작에 있습니다.
    expect(
      tester.getTopLeft(find.byType(Icon).last).dx,
      moreOrLessEquals(
        tester.getTopLeft(find.byKey(TimeBand.cellKey(5))).dx,
        epsilon: 1,
      ),
    );
  });

  testWidgets('지금 줄은 시각 비례 자리에서 칸 위아래 6 넘치고 꼬리표는 줄 위입니다', (tester) async {
    await tester.pumpWidget(_app(_band()));
    final cells = tester.getRect(find.byKey(TimeBand.cellKey(0)));
    final line = tester.getRect(find.byKey(TimeBand.nowLineKey));
    final left = tester.getTopLeft(find.byType(TimeBand)).dx;
    expect(line.width, TimeBand.nowLineWidth);
    expect(line.center.dx - left, moreOrLessEquals(_width / 2));
    expect(cells.top - line.top, moreOrLessEquals(TimeBand.nowOverhang));
    expect(line.bottom - cells.bottom, moreOrLessEquals(TimeBand.nowOverhang));
    final tag = tester.getRect(find.byKey(TimeBand.nowTagKey));
    expect(tag.bottom, moreOrLessEquals(line.top));
    expect(tag.center.dx, moreOrLessEquals(line.center.dx));
    expect(
      find.descendant(
        of: find.byKey(TimeBand.nowTagKey),
        matching: find.text('지금 19:30'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('띠 끝 가까이에서는 꼬리표만 안쪽으로 밀리고 줄은 제자리입니다', (tester) async {
    await tester.pumpWidget(_app(_band(nowFraction: 0.995)));
    final band = tester.getRect(find.byType(TimeBand));
    final tag = tester.getRect(find.byKey(TimeBand.nowTagKey));
    final line = tester.getRect(find.byKey(TimeBand.nowLineKey));
    expect(tag.right, moreOrLessEquals(band.right));
    expect(line.center.dx - band.left, moreOrLessEquals(_width * 0.995));
    await tester.pumpWidget(_app(_band(nowFraction: 0.002)));
    expect(
      tester.getRect(find.byKey(TimeBand.nowTagKey)).left,
      moreOrLessEquals(band.left),
    );
  });

  testWidgets('눈금은 시작 왼쪽, 경계 가운데, 끝 오른쪽이고 날 낱말은 시각 앞 4입니다', (tester) async {
    await tester.pumpWidget(_app(_band()));
    final band = tester.getRect(find.byType(TimeBand));
    final start = find.text('07:30').first;
    final end = find.text('07:30').last;
    expect(tester.getTopLeft(start).dx, moreOrLessEquals(band.left));
    expect(tester.getTopRight(end).dx, moreOrLessEquals(band.right));
    expect(
      tester.getTopLeft(end).dx - tester.getTopRight(find.text('내일')).dx,
      moreOrLessEquals(TimeBand.dayWordGap),
    );
    expect(
      tester.getCenter(find.text('21:30')).dx - band.left,
      moreOrLessEquals(_width * 7 / 12),
    );
    final cells = tester.getRect(find.byKey(TimeBand.cellKey(0)));
    expect(
      tester.getTopLeft(start).dy - cells.bottom,
      moreOrLessEquals(TimeBand.tickGapAbove),
    );
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('지금 꼬리표는 머리 줄(해와 달, 낱말)과 겹치지 않습니다(글자 배율 $scale)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // 07:30 직후처럼 지금 줄이 띠 시작(첫 머리) 바로 위에 있을 때와 가운데일 때.
      for (final fraction in [0.002, 0.5]) {
        await tester.pumpWidget(_app(_band(nowFraction: fraction)));
        final tag = tester.getRect(find.byKey(TimeBand.nowTagKey));
        final heads = [
          ...find.byType(Icon).evaluate(),
          ...find.text('낮').evaluate(),
          ...find.text('밤').evaluate(),
        ].map((element) => tester.getRect(find.byWidget(element.widget)));
        for (final head in heads) {
          expect(
            tag.overlaps(head),
            isFalse,
            reason: 'fraction $fraction: 꼬리표 $tag, 머리 $head',
          );
        }
        // 꼬리표는 여전히 지금 줄 위 끝에 붙어 있습니다.
        expect(
          tag.bottom,
          moreOrLessEquals(tester.getRect(find.byKey(TimeBand.nowLineKey)).top),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('글자 배율 1.0에서 머리 아래 간격은 계약 값 16이고 큰 배율에서만 늘어납니다(A134 ⑪)', (
    tester,
  ) async {
    double gap() {
      final band = tester.getTopLeft(find.byType(TimeBand)).dy;
      final cells = tester.getTopLeft(find.byKey(TimeBand.cellKey(0))).dy;
      // 머리 줄은 최소 높이 24이고 배율 2.0 전에는 내용이 그 안에 들어갑니다.
      return cells - band - TimeBand.headHeight;
    }

    await tester.pumpWidget(_app(_band()));
    // 꼬리표(11 x 1.3)와 넘침 6에서 머리 아래 빈 여백 4를 빼면 16을 넘지 않거나 1px 안입니다.
    expect(gap(), moreOrLessEquals(TimeBand.headGapBelow, epsilon: 0.5));

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(_band()));
    expect(gap(), greaterThan(TimeBand.headGapBelow + 0.5));
  });

  testWidgets('꼬리표가 머리 아래 간격(16)에 들어가면 그 간격은 계약 값 그대로입니다', (tester) async {
    // 꼬리표를 아주 작게 그리면 간격은 heads.gapBelow 16입니다.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(_band()));
    final headBottom = tester.getBottomLeft(find.byType(Icon).first).dy;
    final cellsTop = tester.getTopLeft(find.byKey(TimeBand.cellKey(0))).dy;
    // 머리 줄은 최소 높이 24 안 가운데라 아이콘 아래에 (24 - 16) / 2가 남습니다.
    expect(
      cellsTop - headBottom,
      moreOrLessEquals(TimeBand.headGapBelow + (TimeBand.headHeight - 16) / 2),
    );
  });

  test('고리와 틈 안쪽 채움 모서리는 칸 모서리에서 고리와 틈을 뺀 값입니다', () {
    for (final pick in TimeBandPick.values) {
      expect(
        pick.fillRadius,
        (TimeBand.cellRadius - pick.ringWidth - pick.gapWidth).clamp(
          0,
          double.infinity,
        ),
      );
    }
  });

  testWidgets('en은 지지 한자를 한자 글꼴로 그립니다', (tester) async {
    await tester.pumpWidget(_app(_band(hanjaLabels: true)));
    final typography = tester.element(find.byType(TimeBand)).tokens.typography;
    expect(
      tester.widget<Text>(find.text('진')).style!.fontFamily,
      typography.hanjaPillar.fontFamily,
    );
  });

  testWidgets('스크린리더에서는 띠를 그림으로 숨깁니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_band()));
    expect(find.bySemanticsLabel(RegExp('지금|낮|밤|진')), findsNothing);
    handle.dispose();
  });

  testWidgets('글자 배율 2.0에서도 넘치지 않습니다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(_band()));
    expect(tester.takeException(), isNull);
  });
}
