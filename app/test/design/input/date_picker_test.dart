import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/wheel.dart';

import 'input_harness.dart';

const BirthCalendar _solar = BirthCalendar.solar;
const BirthCalendar _lunar = BirthCalendar.lunar;

BirthDateValue _value({
  BirthCalendar calendar = _solar,
  int year = 1990,
  int month = 3,
  int day = 15,
  bool isLeapMonth = false,
}) => BirthDateValue(
  calendar: calendar,
  year: year,
  month: month,
  day: day,
  isLeapMonth: isLeapMonth,
);

/// 값을 스스로 들고 바꿔 주는 시험용 부모. 바뀐 값은 [changes]에 쌓입니다.
class _Host extends StatefulWidget {
  const new({
    required this.initial,
    required this.changes,
    this.variant = DatePickerVariant.birth,
    this.leapMonth,
    this.solarConfirm,
    super.key,
  });

  final BirthDateValue initial;
  final List<BirthDateValue> changes;
  final DatePickerVariant variant;
  final int? leapMonth;
  final SolarConfirm? solarConfirm;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late BirthDateValue _current = widget.initial;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: BirthDatePicker(
      value: _current,
      onChanged: (value) {
        widget.changes.add(value);
        setState(() => _current = value);
      },
      calendarLabelSolar: '양력',
      calendarLabelLunar: '음력',
      leapMonth: widget.leapMonth,
      solarConfirm: widget.solarConfirm,
      variant: widget.variant,
    ),
  );
}

Widget _picker(
  BirthDateValue value, [
  List<BirthDateValue>? changes,
  int? leapMonth,
  SolarConfirm? solarConfirm,
]) => _Host(
  key: ValueKey((value, leapMonth, solarConfirm?.text)),
  initial: value,
  changes: changes ?? [],
  leapMonth: leapMonth,
  solarConfirm: solarConfirm,
);

Widget _solarOnlyPicker(BirthDateValue value, List<BirthDateValue> changes) =>
    _Host(
      key: ValueKey(value),
      initial: value,
      changes: changes,
      variant: DatePickerVariant.solar,
    );

int _itemCount(WidgetTester tester, Key key) =>
    tester.widget<Wheel>(find.byKey(key)).itemCount;

String _selectedLabel(WidgetTester tester, Key key) {
  final wheel = tester.widget<Wheel>(find.byKey(key));
  return wheel.itemLabel(wheel.selectedIndex);
}

void main() {
  group('BirthDatePicker 월 칸 자리', () {
    test('윤달이 없으면 칸 자리 + 1이 달입니다', () {
      expect(BirthDatePicker.monthAt(0, null), (month: 1, leap: false));
      expect(BirthDatePicker.monthAt(11, null), (month: 12, leap: false));
      expect(BirthDatePicker.monthIndexOf(7, leap: false), 6);
    });

    test('윤4월이면 4월 다음 칸이 윤4월이고 그 뒤는 한 칸씩 밀립니다', () {
      expect(BirthDatePicker.monthAt(3, 4), (month: 4, leap: false));
      expect(BirthDatePicker.monthAt(4, 4), (month: 4, leap: true));
      expect(BirthDatePicker.monthAt(5, 4), (month: 5, leap: false));
      expect(BirthDatePicker.monthAt(12, 4), (month: 12, leap: false));
      for (var i = 0; i < 13; i++) {
        final at = BirthDatePicker.monthAt(i, 4);
        expect(
          BirthDatePicker.monthIndexOf(at.month, leap: at.leap, leapMonth: 4),
          i,
        );
      }
    });

    test('윤12월은 마지막 칸입니다', () {
      expect(BirthDatePicker.monthAt(12, 12), (month: 12, leap: true));
      expect(BirthDatePicker.monthIndexOf(12, leap: true, leapMonth: 12), 12);
    });
  });

  group('BirthDateValue', () {
    test('양력 1900-01-30은 범위 밖, 1900-01-31은 안입니다', () {
      expect(
        _value(year: 1900, month: 1, day: 30).isWithinSupportedRange,
        isFalse,
      );
      expect(
        _value(year: 1900, month: 1, day: 31).isWithinSupportedRange,
        isTrue,
      );
    });

    test('양력 2099-12-31은 안이고 1899년은 밖입니다', () {
      expect(
        _value(year: 2099, month: 12, day: 31).isWithinSupportedRange,
        isTrue,
      );
      expect(_value(year: 1899).isWithinSupportedRange, isFalse);
    });

    test('음력은 연도 범위만 봅니다(1900-01-01 음력도 true)', () {
      expect(
        _value(
          calendar: _lunar,
          year: 1900,
          month: 1,
          day: 1,
        ).isWithinSupportedRange,
        isTrue,
      );
      expect(
        _value(calendar: _lunar, year: 2100).isWithinSupportedRange,
        isFalse,
      );
    });

    test('같은 값은 같고 copyWith로 바뀝니다', () {
      expect(_value(), _value());
      expect(_value().hashCode, _value().hashCode);
      expect(_value().copyWith(day: 16), isNot(_value()));
      expect(_value().copyWith(day: 16).day, 16);
    });
  });

  group('date-picker(birth)', () {
    testWidgets('휠 범위는 1900~2099년입니다', (tester) async {
      await tester.pumpWidget(inputApp(_picker(_value())));
      expect(_itemCount(tester, BirthDatePicker.yearWheelKey), 200);
      expect(_itemCount(tester, BirthDatePicker.monthWheelKey), 12);
      expect(_selectedLabel(tester, BirthDatePicker.yearWheelKey), '1990년');
    });

    testWidgets('양력 2월의 날 휠 최댓값은 그해 날수입니다', (tester) async {
      await tester.pumpWidget(inputApp(_picker(_value(year: 2024, month: 2))));
      expect(_itemCount(tester, BirthDatePicker.dayWheelKey), 29);
      await tester.pumpWidget(
        inputApp(_picker(_value(year: 2023, month: 2, day: 1))),
      );
      expect(_itemCount(tester, BirthDatePicker.dayWheelKey), 28);
    });

    testWidgets('음력은 날 휠이 30일까지입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(_picker(_value(calendar: _lunar, year: 2023, month: 2))),
      );
      expect(_itemCount(tester, BirthDatePicker.dayWheelKey), 30);
    });

    testWidgets('월 휠을 2월로 돌리면 31일이던 날이 그달 끝으로 맞춰집니다', (tester) async {
      final changes = <BirthDateValue>[];
      await tester.pumpWidget(
        inputApp(_picker(_value(year: 2023, month: 1, day: 31), changes)),
      );
      await tester.drag(
        find.byKey(BirthDatePicker.monthWheelKey),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      expect(changes.last.month, 2);
      expect(changes.last.day, 28);
      expect(_itemCount(tester, BirthDatePicker.dayWheelKey), 28);
    });

    testWidgets('윤달 체크는 없고, 음력이면 휠 아래 확인 줄을 그립니다(V31)', (tester) async {
      const confirm = SolarConfirm.text('양력 1990년 5월 15일');
      await tester.pumpWidget(inputApp(_picker(_value(), null, null, confirm)));
      expect(find.byKey(BirthDatePicker.solarConfirmKey), findsNothing);
      await tester.pumpWidget(
        inputApp(_picker(_value(calendar: _lunar), null, null, confirm)),
      );
      await tester.pumpAndSettle();
      expect(find.text('양력 1990년 5월 15일'), findsOneWidget);
      expect(find.byType(CheckRow), findsNothing);
    });

    testWidgets('조회 중이면 확인 줄 자리에 skeleton 한 줄', (tester) async {
      await tester.pumpWidget(
        inputApp(
          _picker(
            _value(calendar: _lunar),
            null,
            null,
            const SolarConfirm.loading(),
          ),
        ),
      );
      final skeleton = tester.widget<SkeletonBlock>(
        find.descendant(
          of: find.byKey(BirthDatePicker.solarConfirmKey),
          matching: find.byType(SkeletonBlock),
        ),
      );
      expect(skeleton.lines, 1);
    });

    testWidgets('그해 윤달이 든 달 다음에 윤N월 칸이 끼워지고, 고르면 윤달입니다', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <BirthDateValue>[];
      await tester.pumpWidget(
        inputApp(_picker(_value(calendar: _lunar, month: 4), changes, 4)),
      );
      expect(_itemCount(tester, BirthDatePicker.monthWheelKey), 13);
      expect(_selectedLabel(tester, BirthDatePicker.monthWheelKey), '4월');

      tester.semantics.increase(find.semantics.byLabel('월'));
      await tester.pumpAndSettle();
      expect(changes.last.month, 4);
      expect(changes.last.isLeapMonth, isTrue);
      expect(_selectedLabel(tester, BirthDatePicker.monthWheelKey), '윤4월');

      tester.semantics.increase(find.semantics.byLabel('월'));
      await tester.pumpAndSettle();
      expect(changes.last.month, 5);
      expect(changes.last.isLeapMonth, isFalse);
      handle.dispose();
    });

    testWidgets('윤달 칸을 모르면 12칸이고 받은 윤달 표시는 보지 않습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          _picker(_value(calendar: _lunar, month: 4, isLeapMonth: true)),
        ),
      );
      expect(_itemCount(tester, BirthDatePicker.monthWheelKey), 12);
      expect(_selectedLabel(tester, BirthDatePicker.monthWheelKey), '4월');
    });

    testWidgets('양력이면 윤달 칸을 받아도 끼우지 않습니다', (tester) async {
      await tester.pumpWidget(inputApp(_picker(_value(month: 4), null, 4)));
      expect(_itemCount(tester, BirthDatePicker.monthWheelKey), 12);
    });

    testWidgets('양력으로 바꾸면 isLeapMonth가 false가 됩니다', (tester) async {
      final changes = <BirthDateValue>[];
      await tester.pumpWidget(
        inputApp(
          _picker(
            _value(
              calendar: _lunar,
              year: 2023,
              month: 2,
              day: 30,
              isLeapMonth: true,
            ),
            changes,
          ),
        ),
      );
      await tester.tap(find.text('양력'));
      await tester.pumpAndSettle();
      expect(changes.single.calendar, _solar);
      expect(changes.single.isLeapMonth, isFalse);
      // 양력 2월은 28일까지라 날도 맞춰집니다.
      expect(changes.single.day, 28);
    });

    testWidgets('음력으로 바꾸면 값은 그대로이고 양력 확인 줄은 없습니다', (tester) async {
      final changes = <BirthDateValue>[];
      await tester.pumpWidget(inputApp(_picker(_value(), changes)));
      await tester.tap(find.text('음력'));
      await tester.pumpAndSettle();
      expect(changes.single.calendar, _lunar);
      expect(changes.single.day, 15);
      expect(find.textContaining('양력으로'), findsNothing);
    });

    testWidgets('휠 한 칸마다 selection 햅틱 한 번', (tester) async {
      final haptics = recordHaptics(tester);
      final changes = <BirthDateValue>[];
      await tester.pumpWidget(inputApp(_picker(_value(), changes)));
      await tester.drag(
        find.byKey(BirthDatePicker.dayWheelKey),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      expect(changes.single.day, 16);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('부모가 값을 바꿔도 햅틱은 나지 않습니다', (tester) async {
      final haptics = recordHaptics(tester);
      Widget plain(int day) => inputApp(
        BirthDatePicker(
          value: _value(day: day),
          onChanged: (_) {},
          calendarLabelSolar: '양력',
          calendarLabelLunar: '음력',
        ),
      );
      await tester.pumpWidget(plain(10));
      await tester.pumpWidget(plain(20));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      expect(_selectedLabel(tester, BirthDatePicker.dayWheelKey), '20일');
    });

    testWidgets('년·월·일 휠이 각각 adjustable Semantics입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_picker(_value())));
      for (final (label, value) in [
        ('연도', '1990년'),
        ('월', '3월'),
        ('일', '15일'),
      ]) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.increase), isTrue, reason: label);
        expect(data.hasAction(SemanticsAction.decrease), isTrue, reason: label);
        expect(data.value, value, reason: label);
      }
      handle.dispose();
    });

    testWidgets('접근성 증가 동작으로 값이 한 칸 바뀝니다', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <BirthDateValue>[];
      await tester.pumpWidget(inputApp(_picker(_value(), changes)));
      tester.semantics.increase(find.semantics.byLabel('일'));
      await tester.pumpAndSettle();
      expect(changes.single.day, 16);
      handle.dispose();
    });

    testWidgets('윤달 칸은 낭독 값도 윤을 붙여 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          _picker(
            _value(calendar: _lunar, month: 4, isLeapMonth: true),
            null,
            4,
          ),
        ),
      );
      var data = tester
          .getSemantics(find.bySemanticsLabel('월'))
          .getSemanticsData();
      expect(data.value, '윤4월');
      expect(data.increasedValue, '5월');
      expect(data.decreasedValue, '4월');
      await tester.pumpWidget(
        inputApp(_picker(_value(calendar: _lunar, month: 4), null, 4)),
      );
      data = tester.getSemantics(find.bySemanticsLabel('월')).getSemanticsData();
      expect(data.value, '4월');
      expect(data.increasedValue, '윤4월');
      handle.dispose();
    });

    testWidgets('양력↔음력 전환마다 selection 햅틱 한 번', (tester) async {
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_picker(_value())));
      await tester.tap(find.text('음력'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      await tester.tap(find.text('양력'));
      await tester.pumpAndSettle();
      expect(haptics, hasLength(2));
    });

    testWidgets('빠르게 튕겨도 부모의 재빌드가 관성 스크롤을 끊지 않습니다', (tester) async {
      final changes = <BirthDateValue>[];
      await tester.pumpWidget(inputApp(_picker(_value(year: 1950), changes)));
      await tester.fling(
        find.byKey(BirthDatePicker.yearWheelKey),
        const Offset(0, -300),
        2000,
      );
      await tester.pumpAndSettle();
      // 튕긴 만큼 여러 칸을 지나가야 하고(관성이 살아 있음), 마지막 값이 휠이 멈춘 칸입니다.
      expect(changes.length, greaterThan(3));
      final shown = _selectedLabel(tester, BirthDatePicker.yearWheelKey);
      expect(shown, '${changes.last.year}년');
      final years = [for (final c in changes) c.year];
      for (var i = 1; i < years.length; i++) {
        // 되돌아가는 칸이 없어야 합니다(한 방향으로 단조 증가).
        expect(years[i], greaterThan(years[i - 1]));
      }
    });

    testWidgets('부모가 따라 바꿔도 튕긴 휠은 따라 바꾸지 않을 때와 같은 칸에 멈춥니다', (tester) async {
      Future<int> flingTo({required bool controlled}) async {
        var selected = 100;
        await tester.pumpWidget(
          inputApp(
            StatefulBuilder(
              builder: (context, setState) => Wheel(
                itemCount: 200,
                selectedIndex: selected,
                itemLabel: (i) => '$i',
                semanticLabel: '시험',
                onSelectedIndexChanged: (i) {
                  if (controlled) {
                    setState(() => selected = i);
                  } else {
                    selected = i;
                  }
                },
              ),
            ),
          ),
        );
        await tester.fling(find.byType(Wheel), const Offset(0, -300), 2000);
        await tester.pumpAndSettle();
        return selected;
      }

      final free = await flingTo(controlled: false);
      final followed = await flingTo(controlled: true);
      expect(free, greaterThan(105));
      expect(followed, free);
    });

    group('date-picker(solar)', () {
      testWidgets('양력·음력 선택과 윤달 줄을 그리지 않고 휠은 그대로입니다', (tester) async {
        await tester.pumpWidget(inputApp(_solarOnlyPicker(_value(), [])));
        expect(find.byType(Segmented<BirthCalendar>), findsNothing);
        expect(find.text('양력'), findsNothing);
        expect(find.text('음력'), findsNothing);
        expect(find.byType(CheckRow), findsNothing);
        expect(_itemCount(tester, BirthDatePicker.yearWheelKey), 200);
        expect(_itemCount(tester, BirthDatePicker.monthWheelKey), 12);
      });

      testWidgets('휠을 돌려 바뀐 값은 늘 양력이고 윤달이 아닙니다', (tester) async {
        final changes = <BirthDateValue>[];
        await tester.pumpWidget(inputApp(_solarOnlyPicker(_value(), changes)));
        final wheel = tester.widget<Wheel>(
          find.byKey(BirthDatePicker.dayWheelKey),
        );
        wheel.onSelectedIndexChanged(19);
        await tester.pump();
        expect(changes.single.calendar, _solar);
        expect(changes.single.isLeapMonth, isFalse);
        expect(changes.single.day, 20);
      });

      testWidgets('음력 값이 들어와도 양력 날수로 그리고 양력으로 돌려줍니다', (tester) async {
        final changes = <BirthDateValue>[];
        await tester.pumpWidget(
          inputApp(
            _solarOnlyPicker(
              _value(calendar: _lunar, month: 2, day: 10, isLeapMonth: true),
              changes,
            ),
          ),
        );
        expect(find.byType(CheckRow), findsNothing);
        expect(_itemCount(tester, BirthDatePicker.dayWheelKey), 28);
        tester
            .widget<Wheel>(find.byKey(BirthDatePicker.dayWheelKey))
            .onSelectedIndexChanged(4);
        await tester.pump();
        expect(changes.single.calendar, _solar);
        expect(changes.single.isLeapMonth, isFalse);
      });

      testWidgets('2024-02-29에서 연도를 2025로 바꾸면 2월 28일로 맞춰집니다', (tester) async {
        final changes = <BirthDateValue>[];
        await tester.pumpWidget(
          inputApp(
            _solarOnlyPicker(_value(year: 2024, month: 2, day: 29), changes),
          ),
        );
        tester
            .widget<Wheel>(find.byKey(BirthDatePicker.yearWheelKey))
            .onSelectedIndexChanged(2025 - BirthDateValue.minYear);
        await tester.pump();
        expect(changes.single.year, 2025);
        expect(changes.single.month, 2);
        expect(changes.single.day, 28);
      });

      testWidgets('음력 2월 30일이 들어오면 표시도 값도 양력 그달 끝으로 맞춥니다', (tester) async {
        final changes = <BirthDateValue>[];
        await tester.pumpWidget(
          inputApp(
            _solarOnlyPicker(
              _value(calendar: _lunar, year: 2025, month: 2, day: 30),
              changes,
            ),
          ),
        );
        expect(_selectedLabel(tester, BirthDatePicker.dayWheelKey), '28일');
        tester
            .widget<Wheel>(find.byKey(BirthDatePicker.monthWheelKey))
            .onSelectedIndexChanged(2);
        await tester.pump();
        expect(changes.single.month, 3);
        expect(changes.single.day, 28);
      });
    });

    testWidgets('calendar 변형은 휠이 아니라 MonthDatePicker라 ArgumentError입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        inputApp(
          BirthDatePicker(
            variant: DatePickerVariant.calendar,
            value: _value(),
            onChanged: (_) {},
            calendarLabelSolar: '양력',
            calendarLabelLunar: '음력',
          ),
        ),
      );
      expect(tester.takeException(), isA<ArgumentError>());
    });
  });
}
