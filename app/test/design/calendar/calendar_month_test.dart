import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

DayCellData _cellOf(CalendarDate date) => DayCellData(
  date: date,
  luck: date.day % 3 == 0 ? DayLuck.good : DayLuck.neutral,
  lunarText: '${date.day}',
  semanticLabel: '${date.month}월 ${date.day}일',
);

/// 달 격자를 너비 336에 놓고, 받은 달 넘김·선택을 [log]에 모읍니다.
class _Harness extends StatefulWidget {
  const new({
    required this.initial,
    required this.log,
    this.loading = false,
    this.isDateEnabled,
  });

  final CalendarMonth initial;
  final List<Object> log;
  final bool loading;
  final bool Function(CalendarDate date)? isDateEnabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late CalendarMonth _month = widget.initial;
  CalendarDate? _selected;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 336,
      child: CalendarMonthView(
        month: _month,
        title: '${_month.year}년 ${_month.month}월',
        weekdayLabels: _weekdays,
        cellOf: _cellOf,
        loading: widget.loading,
        today: CalendarDate(2026, 10, 16),
        selected: _selected,
        skeletonDelay: Duration.zero,
        skeletonAnimated: false,
        isDateEnabled: widget.isDateEnabled,
        onSelect: (date) {
          widget.log.add(date);
          setState(() => _selected = date);
        },
        onMonthChange: (month) {
          widget.log.add(month);
          setState(() => _month = month);
        },
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  CalendarMonth? month,
  List<Object>? log,
  bool loading = false,
  double textScale = 1,
  bool Function(CalendarDate date)? isDateEnabled,
}) => tester.pumpWidget(
  inputApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: _Harness(
          initial: month ?? const CalendarMonth(2026, 10),
          log: log ?? [],
          loading: loading,
          isDateEnabled: isDateEnabled,
        ),
      ),
    ),
  ),
);

Finder _cellFor(int month, int day) => find.byWidgetPredicate(
  (w) => w is DayCell && w.data.date.month == month && w.data.date.day == day,
);

void main() {
  testWidgets('주 시작은 일요일: 2026-10 첫 칸은 9월 27일(일), 42칸', (tester) async {
    await _pump(tester);
    final cells = tester.widgetList<DayCell>(find.byType(DayCell)).toList();
    expect(cells, hasLength(42));
    expect(cells.first.data.date, CalendarDate(2026, 9, 27));
    expect(cells.last.data.date, CalendarDate(2026, 11, 7));
    // 바깥 달 표시, 오늘 표시.
    expect(cells.first.outsideMonth, isTrue);
    expect(tester.widget<DayCell>(_cellFor(10, 16)).isToday, isTrue);
    expect(tester.widget<DayCell>(_cellFor(10, 1)).outsideMonth, isFalse);
    // 첫 칸과 일곱째 칸은 같은 줄, 여덟째 칸은 다음 줄.
    final first = tester.getRect(find.byWidget(cells.first));
    final seventh = tester.getRect(find.byWidget(cells[6]));
    final eighth = tester.getRect(find.byWidget(cells[7]));
    expect(seventh.top, first.top);
    expect(eighth.top, first.bottom + CalendarMonthView.gridGap);
    expect(cells[1].data.date.weekday, DateTime.monday);
    // 칸 사이 2px.
    final second = tester.getRect(find.byWidget(cells[1]));
    expect(second.left, closeTo(first.right + CalendarMonthView.gridGap, 0.01));
  });

  testWidgets('요일 머리: 일·토만 색, 나머지 text.secondary, 날짜 숫자는 무색', (tester) async {
    await _pump(tester);
    final tokens = tester.element(find.byType(CalendarMonthView)).tokens;
    Color? colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color;
    expect(colorOf('일'), tokens.colors.calendarWeekdaySun);
    expect(colorOf('토'), tokens.colors.calendarWeekdaySat);
    for (final label in ['월', '화', '수', '목', '금']) {
      expect(colorOf(label), tokens.colors.textSecondary, reason: label);
    }
    expect(
      tester.widget<Text>(find.text('일')).style!.fontSize,
      tokens.typography.captionMd.fontSize,
    );
    // 일요일(10월 4일)·토요일(10월 10일) 숫자는 본문색.
    for (final day in [4, 10]) {
      final number = tester.widget<Text>(
        find.descendant(
          of: find.descendant(
            of: _cellFor(10, day),
            matching: find.byKey(DayCell.numberKey),
          ),
          matching: find.byType(Text),
        ),
      );
      expect(number.style!.color, tokens.colors.textPrimary, reason: '$day');
    }
    expect(
      tester.getSize(find.byKey(CalendarMonthView.weekdaysKey)).height,
      CalendarMonthView.weekdaysHeight,
    );
  });

  testWidgets('제목은 type.subtitle text.primary', (tester) async {
    await _pump(tester);
    final tokens = tester.element(find.byType(CalendarMonthView)).tokens;
    final title = tester.widget<Text>(find.text('2026년 10월'));
    expect(title.style!.fontSize, tokens.typography.subtitle.fontSize);
    expect(title.style!.color, tokens.colors.textPrimary);
  });

  testWidgets('칸 글자는 2.0을 줘도 1.3으로 그립니다', (tester) async {
    await _pump(tester, textScale: 2);
    final number = tester.element(
      find.descendant(of: _cellFor(10, 1), matching: find.text('1')).first,
    );
    expect(MediaQuery.textScalerOf(number).scale(10), closeTo(13, 0.001));
  });

  testWidgets('날짜를 누르면 onSelect, 선택 표시', (tester) async {
    final log = <Object>[];
    await _pump(tester, log: log);
    await tester.tap(_cellFor(10, 21));
    await tester.pumpAndSettle();
    expect(log, [CalendarDate(2026, 10, 21)]);
    expect(tester.widget<DayCell>(_cellFor(10, 21)).isSelected, isTrue);
  });

  testWidgets('다음·이전 누르면 달 넘김, 격자만 appear.seep', (tester) async {
    final log = <Object>[];
    await _pump(tester, log: log);
    await tester.tap(find.byKey(CalendarMonthView.nextKey));
    await tester.pump();
    expect(log, [const CalendarMonth(2026, 11)]);
    expect(find.text('2026년 11월'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    // 격자는 스미는 중이고 머리(제목)는 그대로 보입니다.
    final gridFade = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(CalendarMonthView.gridKey),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(gridFade.opacity, inExclusiveRange(0, 1));
    expect(
      find.ancestor(of: find.text('2026년 11월'), matching: find.byType(Opacity)),
      findsNothing,
    );
    // 가로 이동은 없습니다(격자와 격자 노드 사이에 이동 위젯이 없음, 바깥은 앱 페이지).
    int translations(Key key) => find
        .ancestor(
          of: find.byKey(key),
          matching: find.byType(FractionalTranslation),
        )
        .evaluate()
        .length;
    expect(
      translations(CalendarMonthView.gridKey),
      translations(CalendarMonthView.tableKey),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CalendarMonthView.prevKey));
    await tester.pumpAndSettle();
    expect(log.last, const CalendarMonth(2026, 10));
    expect(InteractionPattern.appearSeep.id, 'appear.seep');
  });

  testWidgets('밀기: 왼쪽 → 다음 달, 오른쪽 → 이전 달', (tester) async {
    final log = <Object>[];
    await _pump(tester, log: log);
    await tester.fling(
      find.byKey(CalendarMonthView.gridKey),
      const Offset(-200, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(log, [const CalendarMonth(2026, 11)]);
    await tester.fling(
      find.byKey(CalendarMonthView.gridKey),
      const Offset(200, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(log, [const CalendarMonth(2026, 11), const CalendarMonth(2026, 10)]);
    // 느리게 끌어도 충분히 밀면 넘어갑니다.
    await tester.drag(
      find.byKey(CalendarMonthView.gridKey),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(log.last, const CalendarMonth(2026, 11));
  });

  testWidgets('1900-01에서 이전 비활성: 흐린 아이콘, enabled false, 밀어도 안 넘어감', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final log = <Object>[];
    await _pump(tester, month: const CalendarMonth(1900, 1), log: log);
    final tokens = tester.element(find.byType(CalendarMonthView)).tokens;
    final prev = tester
        .getSemantics(find.byKey(CalendarMonthView.prevKey))
        .getSemanticsData();
    expect(prev.flagsCollection.isEnabled, Tristate.isFalse);
    expect(prev.label, '이전 달');
    final prevIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(CalendarMonthView.prevKey),
        matching: find.byType(Icon),
      ),
    );
    expect(prevIcon.color, tokens.colors.disabledFg);
    await tester.tap(find.byKey(CalendarMonthView.prevKey));
    await tester.fling(
      find.byKey(CalendarMonthView.gridKey),
      const Offset(200, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    final next = tester
        .getSemantics(find.byKey(CalendarMonthView.nextKey))
        .getSemanticsData();
    expect(next.flagsCollection.isEnabled, Tristate.isTrue);
    expect(next.label, '다음 달');
    handle.dispose();
  });

  testWidgets('2099-12에서 다음 비활성', (tester) async {
    final log = <Object>[];
    // harness 상태를 버리고 새 달로 엽니다.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, month: const CalendarMonth(2099, 12), log: log);
    await tester.tap(find.byKey(CalendarMonthView.nextKey));
    await tester.fling(
      find.byKey(CalendarMonthView.gridKey),
      const Offset(-200, 0),
      800,
    );
    await tester.pumpAndSettle();
    expect(log, isEmpty);
  });

  testWidgets('이전·다음 터치 영역 44px', (tester) async {
    await _pump(tester);
    expect(
      tester.getSize(find.byKey(CalendarMonthView.prevKey)),
      const Size.square(44),
    );
    expect(
      tester.getSize(find.byKey(CalendarMonthView.nextKey)),
      const Size.square(44),
    );
  });

  testWidgets('Semantics: grid(table, "N년 M월")·요일 머리·gridcell(semanticLabel)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final grid = tester
        .getSemantics(find.byKey(CalendarMonthView.tableKey))
        .getSemanticsData();
    expect(grid.role, SemanticsRole.table);
    expect(grid.label, '2026년 10월');
    final cell = tester.getSemantics(_cellFor(10, 11)).getSemanticsData();
    expect(cell.role, SemanticsRole.cell);
    expect(cell.label, '10월 11일');
    expect(
      tester.getSemantics(find.text('일')).getSemanticsData().role,
      SemanticsRole.columnHeader,
    );
    handle.dispose();
  });

  testWidgets('loading: 이 달 칸의 길흉 채우기·도장 자리만 skeleton, 숫자는 바로', (tester) async {
    await _pump(tester, loading: true);
    final cell = find.byKey(
      CalendarMonthView.cellKey(CalendarDate(2026, 10, 5)),
    );
    final fillBone = find.descendant(
      of: cell,
      matching: find.byKey(CalendarMonthView.fillBoneKey),
    );
    final sealBone = find.descendant(
      of: cell,
      matching: find.byKey(CalendarMonthView.sealBoneKey),
    );
    expect(fillBone, findsOneWidget);
    expect(sealBone, findsOneWidget);
    // 채우기 자리는 칸 전체, 도장 자리는 숫자 상자 가운데 26px.
    final dayCell = find.descendant(of: cell, matching: find.byType(DayCell));
    expect(tester.getRect(fillBone), tester.getRect(dayCell));
    final numberBox = tester.getRect(
      find.descendant(of: dayCell, matching: find.byKey(DayCell.numberKey)),
    );
    expect(tester.getSize(sealBone), const Size.square(26));
    expect(tester.getCenter(sealBone), numberBox.center);
    expect(
      find.descendant(of: sealBone, matching: find.byType(SkeletonBone)),
      findsOneWidget,
    );
    // 도장 자리는 도장 모양으로 잘립니다.
    final clip = tester.widget<ClipPath>(
      find.descendant(of: sealBone, matching: find.byType(ClipPath)),
    );
    expect(clip.clipper, isA<SealShapeClipper>());
    // 숫자는 바로 보입니다.
    expect(
      find.descendant(
        of: find.descendant(
          of: dayCell,
          matching: find.byKey(DayCell.numberKey),
        ),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
    // 바깥 달 칸에는 skeleton이 없습니다.
    final outside = find.byKey(
      CalendarMonthView.cellKey(CalendarDate(2026, 9, 27)),
    );
    expect(
      find.descendant(
        of: outside,
        matching: find.byKey(CalendarMonthView.fillBoneKey),
      ),
      findsNothing,
    );
    expect(find.byType(SkeletonBone), findsNWidgets(31 * 2));

    // 불러오기가 끝나면 skeleton은 빠집니다.
    await _pump(tester);
    expect(find.byType(SkeletonBone), findsNothing);
  });

  testWidgets('범례: 10px 견본(radius.xs) + caption.md 낱말', (tester) async {
    await tester.pumpWidget(
      inputApp(
        Builder(
          builder: (context) {
            final colors = context.tokens.colors;
            return CalendarMonthView(
              month: const CalendarMonth(2026, 10),
              title: '2026년 10월',
              weekdayLabels: _weekdays,
              cellOf: _cellOf,
              loading: false,
              today: CalendarDate(2026, 10, 16),
              onSelect: (_) {},
              onMonthChange: (_) {},
              legend: [
                (swatch: colors.calendarGoodBg, label: '잘 풀리는 날'),
                (swatch: colors.calendarCautionBg, label: '조심할 날'),
              ],
              legendIdentifier: 'calendar.legend.body',
            );
          },
        ),
      ),
    );
    final tokens = tester.element(find.byType(CalendarMonthView)).tokens;
    expect(find.byKey(const ValueKey('calendar.legend.body')), findsOneWidget);
    final swatches = find.byKey(CalendarMonthView.legendSwatchKey);
    expect(swatches, findsNWidgets(2));
    expect(tester.getSize(swatches.first), const Size.square(10));
    final decoration =
        tester.widget<DecoratedBox>(swatches.first).decoration as BoxDecoration;
    expect(decoration.color, tokens.colors.calendarGoodBg);
    final label = tester.widget<Text>(find.text('조심할 날'));
    expect(label.style!.fontSize, tokens.typography.captionMd.fontSize);
    expect(label.style!.color, tokens.colors.textSecondary);
  });

  /// [date] 칸을 눌러도 onSelect가 없고 Semantics가 비활성인지 확인합니다.
  Future<void> expectDisabledCell(
    WidgetTester tester,
    CalendarDate date,
    List<Object> log,
  ) async {
    final cell = find.descendant(
      of: find.byKey(CalendarMonthView.cellKey(date)),
      matching: find.byType(DayCell),
    );
    final widget = tester.widget<DayCell>(cell);
    expect(widget.disabled, isTrue, reason: '$date');
    expect(widget.onTap, isNull, reason: '$date');
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(log, isEmpty, reason: '$date');
    expect(
      tester.getSemantics(cell).getSemanticsData().flagsCollection.isEnabled,
      Tristate.isFalse,
      reason: '$date',
    );
  }

  testWidgets('지원 범위(1900-01-31 ~ 2099-12-31) 밖 날짜 칸은 누를 수 없습니다', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final log = <Object>[];
    await _pump(tester, month: const CalendarMonth(1900, 1), log: log);
    await expectDisabledCell(tester, CalendarDate(1899, 12, 31), log);
    await expectDisabledCell(tester, CalendarDate(1900, 1, 15), log);
    expect(
      tester.widget<DayCell>(_cellFor(1, 31)).disabled,
      isFalse,
      reason: '1900-01-31은 범위 안',
    );

    // harness 상태를 버리고 새 달로 엽니다.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, month: const CalendarMonth(2099, 12), log: log);
    await expectDisabledCell(tester, CalendarDate(2100, 1, 1), log);
    handle.dispose();
  });

  testWidgets('isDateEnabled가 false인 날짜 칸은 누를 수 없습니다', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <Object>[];
    final limit = CalendarDate(2026, 10, 16);
    await _pump(
      tester,
      log: log,
      isDateEnabled: (date) => date.compareTo(limit) <= 0,
    );
    await expectDisabledCell(tester, CalendarDate(2026, 10, 17), log);
    await tester.tap(_cellFor(10, 16));
    await tester.pumpAndSettle();
    expect(log, [limit]);
    handle.dispose();
  });

  testWidgets('밀기: 속도가 임계를 넘으면 끈 거리보다 속도 방향이 먼저입니다', (tester) async {
    final log = <Object>[];
    await _pump(tester, log: log);
    // 이벤트 시각을 직접 매겨야 속도가 계산됩니다(기본값은 모두 0).
    var at = Duration.zero;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(CalendarMonthView.gridKey)),
    );
    // 왼쪽으로 천천히 120px 끈 뒤 오른쪽으로 빠르게 60px 던집니다(누적 -60px).
    for (var i = 0; i < 10; i++) {
      at += const Duration(milliseconds: 50);
      await gesture.moveBy(const Offset(-12, 0), timeStamp: at);
    }
    for (var i = 0; i < 6; i++) {
      at += const Duration(milliseconds: 16);
      await gesture.moveBy(const Offset(10, 0), timeStamp: at);
    }
    await gesture.up(timeStamp: at);
    await tester.pumpAndSettle();
    expect(log, [const CalendarMonth(2026, 9)]);
  });

  testWidgets('loading: 격자 밖에 불러오는 중 노드 하나를 둡니다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, loading: true);
    expect(find.bySemanticsLabel('불러오는 중'), findsOneWidget);
    final node = tester.getSemantics(find.byKey(CalendarMonthView.loadingKey));
    expect(node.getSemanticsData().role, SemanticsRole.loadingSpinner);
    // table의 자식이 아닙니다(table 자식은 row만).
    expect(
      find.ancestor(
        of: find.byKey(CalendarMonthView.loadingKey),
        matching: find.byKey(CalendarMonthView.tableKey),
      ),
      findsNothing,
    );
    await _pump(tester);
    expect(find.byKey(CalendarMonthView.loadingKey), findsNothing);
    handle.dispose();
  });

  testWidgets('달 제목은 격자 이름으로 한 번만 읽습니다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('2026년 10월'), findsOneWidget);
    // 달을 넘기면 바뀐 이름을 알립니다.
    final grid = tester
        .getSemantics(find.byKey(CalendarMonthView.tableKey))
        .getSemanticsData();
    expect(grid.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  test('명세 상태 id', () {
    expect(CalendarMonthView.spec.id, 'calendar-month');
    expect(CalendarMonthView.spec.states, {'monthChanged', 'loading'});
  });
}
