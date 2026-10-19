import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

final _date = CalendarDate(2026, 10, 11);

DayCellData _data({
  DayLuck? luck,
  String? lunarText = '9.1',
  bool lunarBold = false,
  bool diaryWritten = false,
  int eventCount = 0,
  String semanticLabel = '10월 11일 일요일, 음력 9.1',
}) => DayCellData(
  date: _date,
  luck: luck,
  lunarText: lunarText,
  lunarBold: lunarBold,
  diaryWritten: diaryWritten,
  eventCount: eventCount,
  semanticLabel: semanticLabel,
);

/// 너비 48 칸 하나를 놓은 앱. [textScale]로 시스템 글자 크기를 바꿉니다.
Widget _app(Widget cell, {double textScale = 1, bool reduceMotion = false}) =>
    inputApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 48, child: cell),
          ),
        ),
      ),
    );

DayCell _cell({
  DayCellData? data,
  bool isToday = false,
  bool isSelected = false,
  bool outsideMonth = false,
  bool disabled = false,
  VoidCallback? onTap,
}) => DayCell(
  data: data ?? _data(),
  isToday: isToday,
  isSelected: isSelected,
  outsideMonth: outsideMonth,
  disabled: disabled,
  onTap: onTap ?? () {},
);

MyungliTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DayCell)).tokens;

Text _number(WidgetTester tester) => tester.widget<Text>(
  find.descendant(
    of: find.byKey(DayCell.numberKey),
    matching: find.byType(Text),
  ),
);

/// 칸 안 겹침 층(Stack 자식)의 키를 아래부터 순서대로 모읍니다.
List<Key> _layerKeys(WidgetTester tester) {
  final stack = tester.widget<Stack>(find.byKey(DayCell.layersKey));
  return [
    for (final child in stack.children)
      if (child.key != null && DayCell.layerOrder.contains(child.key))
        child.key!,
  ];
}

void main() {
  testWidgets('층 순서: luck-fill → diary-seal → today-outline → number → '
      'selected-underline → event-dot', (tester) async {
    await tester.pumpWidget(
      _app(
        _cell(
          data: _data(luck: DayLuck.good, diaryWritten: true, eventCount: 2),
          isToday: true,
          isSelected: true,
        ),
      ),
    );
    expect(_layerKeys(tester), DayCell.layerOrder);
    expect(DayCell.layerOrder, [
      DayCell.luckFillKey,
      DayCell.diarySealKey,
      DayCell.todayOutlineKey,
      DayCell.numberKey,
      DayCell.underlineKey,
      DayCell.eventDotKey,
    ]);
  });

  testWidgets('높이 62·radius.sm 길흉 채우기: good·caution 색, neutral·null은 채우지 않음', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_cell(data: _data(luck: DayLuck.good))));
    final tokens = _tokens(tester);
    expect(tester.getSize(find.byType(DayCell)).height, DayCell.height);
    BoxDecoration fill() =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(DayCell.luckFillKey),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(fill().color, tokens.colors.calendarGoodBg);
    expect(
      fill().borderRadius,
      const BorderRadius.all(Radius.circular(Radii.sm)),
    );

    await tester.pumpWidget(_app(_cell(data: _data(luck: DayLuck.caution))));
    expect(fill().color, tokens.colors.calendarCautionBg);

    await tester.pumpWidget(_app(_cell(data: _data(luck: DayLuck.neutral))));
    expect(find.byKey(DayCell.luckFillKey), findsNothing);

    await tester.pumpWidget(_app(_cell(data: _data())));
    expect(find.byKey(DayCell.luckFillKey), findsNothing);
  });

  testWidgets('숫자는 위쪽 32px 상자 가운데, numeric.calendar 본문색', (tester) async {
    await tester.pumpWidget(_app(_cell()));
    final tokens = _tokens(tester);
    final box = tester.getRect(find.byKey(DayCell.numberKey));
    final cell = tester.getRect(find.byType(DayCell));
    expect(box.height, DayCell.numberBoxSize);
    expect(box.top - cell.top, DayCell.numberBoxTop);
    final number = _number(tester);
    expect(number.data, '11');
    expect(number.style!.fontSize, tokens.typography.numericCalendar.fontSize);
    expect(number.style!.color, tokens.colors.textPrimary);
    expect(tester.getCenter(find.text('11')).dx, closeTo(cell.center.dx, 0.01));
    expect(tester.getCenter(find.text('11')).dy, closeTo(box.center.dy, 0.01));
  });

  testWidgets('일기 도장 soft·오늘 윤곽 outline: 26px, 숫자 상자 가운데', (tester) async {
    await tester.pumpWidget(
      _app(_cell(data: _data(diaryWritten: true), isToday: true)),
    );
    final box = tester.getRect(find.byKey(DayCell.numberKey));
    for (final (key, variant) in [
      (DayCell.diarySealKey, SealVariant.soft),
      (DayCell.todayOutlineKey, SealVariant.outline),
    ]) {
      final seal = find.descendant(
        of: find.byKey(key),
        matching: find.byType(Seal),
      );
      expect(tester.widget<Seal>(seal).variant, variant);
      expect(tester.widget<Seal>(seal).size, SealSize.cell);
      expect(tester.getSize(seal), const Size.square(26));
      expect(tester.getCenter(seal), box.center);
    }
    // 일기 쓴 날의 숫자는 본문색입니다.
    expect(_number(tester).style!.color, _tokens(tester).colors.textPrimary);
  });

  testWidgets('selected: 숫자 action.primary 700 + 14×2 밑줄', (tester) async {
    await tester.pumpWidget(_app(_cell(isSelected: true)));
    final tokens = _tokens(tester);
    final style = _number(tester).style!;
    expect(style.color, tokens.colors.actionPrimary);
    expect(style.fontWeight, FontWeight.w700);
    final bar = find.byKey(DayCell.underlineBarKey);
    expect(tester.getSize(bar), const Size(14, 2));
    final decoration =
        tester.widget<DecoratedBox>(bar).decoration as BoxDecoration;
    expect(decoration.color, tokens.colors.actionPrimary);
    // 숫자 바로 아래 2px.
    final textRect = tester.getRect(find.text('11'));
    expect(tester.getRect(bar).top, closeTo(textRect.bottom + 2, 0.01));
    expect(tester.getCenter(bar).dx, closeTo(textRect.center.dx, 0.01));
  });

  testWidgets('선택되면 밑줄이 가운데에서 자라고(420ms), 동작 줄이기면 투명도만', (tester) async {
    await tester.pumpWidget(_app(_cell()));
    expect(find.byKey(DayCell.underlineBarKey), findsNothing);
    await tester.pumpWidget(_app(_cell(isSelected: true)));
    await tester.pump(const Duration(milliseconds: 100));
    final grow = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(DayCell.underlineBarKey),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(grow.transform.storage[0], inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(DayCell.underlineBarKey),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[0],
      1,
    );

    await tester.pumpWidget(_app(_cell(), reduceMotion: true));
    await tester.pumpWidget(_app(_cell(isSelected: true), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.ancestor(
        of: find.byKey(DayCell.underlineBarKey),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    final fade = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(DayCell.underlineBarKey),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(fade.opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
  });

  testWidgets('selectedOnDiary: 숫자 seal.on-soft 700', (tester) async {
    await tester.pumpWidget(
      _app(_cell(data: _data(diaryWritten: true), isSelected: true)),
    );
    final style = _number(tester).style!;
    expect(style.color, _tokens(tester).colors.sealOnSoft);
    expect(style.fontWeight, FontWeight.w700);
  });

  testWidgets('hasEvent: 음력 아래 action.primary 점 5px', (tester) async {
    await tester.pumpWidget(_app(_cell()));
    expect(find.byKey(DayCell.eventDotKey), findsNothing);
    await tester.pumpWidget(_app(_cell(data: _data(eventCount: 3))));
    final dot = find.descendant(
      of: find.byKey(DayCell.eventDotKey),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(dot), const Size.square(5));
    final decoration =
        tester.widget<DecoratedBox>(dot).decoration as BoxDecoration;
    expect(decoration.color, _tokens(tester).colors.actionPrimary);
    expect(decoration.shape, BoxShape.circle);
    final lunar = tester.getRect(find.byKey(DayCell.lunarKey));
    expect(tester.getRect(dot).top, greaterThanOrEqualTo(lunar.bottom));
    expect(
      tester.getRect(dot).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(DayCell)).bottom),
    );
  });

  testWidgets('음력: caption.sm 10.5px text.secondary, 절기는 굵게, null이면 그리지 않음', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_cell()));
    final tokens = _tokens(tester);
    var style = tester.widget<Text>(find.text('9.1')).style!;
    expect(style.fontSize, 10.5);
    expect(style.color, tokens.colors.textSecondary);
    expect(style.fontWeight, tokens.typography.captionSm.fontWeight);
    expect(
      tester.getRect(find.byKey(DayCell.lunarKey)).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(DayCell.numberKey)).bottom,
      ),
    );

    await tester.pumpWidget(
      _app(_cell(data: _data(lunarText: '한로', lunarBold: true))),
    );
    style = tester.widget<Text>(find.text('한로')).style!;
    expect(style.fontWeight, FontWeight.w700);

    await tester.pumpWidget(_app(_cell(data: _data(lunarText: null))));
    expect(find.byKey(DayCell.lunarKey), findsNothing);
  });

  testWidgets('outsideMonth: 숫자 opacity 0.35, 길흉 채우기 없음', (tester) async {
    await tester.pumpWidget(
      _app(_cell(data: _data(luck: DayLuck.good), outsideMonth: true)),
    );
    expect(find.byKey(DayCell.luckFillKey), findsNothing);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('11'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, DayCell.outsideMonthOpacity);
    expect(DayCell.outsideMonthOpacity, 0.35);
  });

  testWidgets('disabled: 숫자 disabled.fg, 눌러도 부르지 않고 enabled false', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_app(_cell(disabled: true, onTap: () => taps++)));
    expect(_number(tester).style!.color, _tokens(tester).colors.disabledFg);
    await tester.tap(find.byType(DayCell));
    expect(taps, 0);
    final data = tester.getSemantics(find.byType(DayCell)).getSemanticsData();
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('누르면 onTap, 눌림은 press.ink', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(_cell(onTap: () => taps++)));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DayCell)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));
    expect(paintsInk(tester, inkLayer(find.byType(DayCell))), isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('칸 글자는 1.3배에서 멈춥니다(2.0을 줘도 1.3)', (tester) async {
    await tester.pumpWidget(_app(_cell(), textScale: 2));
    final element = tester.element(find.text('11'));
    expect(MediaQuery.textScalerOf(element).scale(10), closeTo(13, 0.001));
    expect(DayCell.textScaleMax, 1.3);
  });

  testWidgets('Semantics: semanticLabel을 읽고 선택을 알립니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_cell(isSelected: true)));
    final data = tester.getSemantics(find.byType(DayCell)).getSemanticsData();
    expect(data.label, '10월 11일 일요일, 음력 9.1');
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('격자 줄 안이면 Semantics role은 cell', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Semantics(
          container: true,
          role: SemanticsRole.table,
          child: Semantics(
            container: true,
            role: SemanticsRole.row,
            child: DayCellGridRow(child: _cell()),
          ),
        ),
      ),
    );
    final data = tester.getSemantics(find.byType(DayCell)).getSemanticsData();
    expect(data.role, SemanticsRole.cell);
    handle.dispose();
  });

  test('명세 상태 id', () {
    expect(DayCell.spec.id, 'day-cell');
    expect(DayCell.spec.states, {
      'diaryWritten',
      'today',
      'selected',
      'selectedOnDiary',
      'hasEvent',
      'outsideMonth',
      'pressed',
      'disabled',
    });
  });
}
