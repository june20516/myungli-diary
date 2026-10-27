import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/design/components/input/wheel.dart';

import 'input_harness.dart';

class _Host extends StatefulWidget {
  const new({
    required this.variant,
    required this.initial,
    required this.changes,
    this.unknown = false,
    this.sijinConfirm,
    super.key,
  });

  final TimePickerVariant variant;
  final TimeOfDay initial;
  final List<TimeOfDay> changes;
  final bool unknown;
  final String? sijinConfirm;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late TimeOfDay _current = widget.initial;
  late bool _unknown = widget.unknown;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: TimePicker(
      variant: widget.variant,
      value: _current,
      onChanged: (value) {
        widget.changes.add(value);
        setState(() => _current = value);
      },
      unknown: _unknown,
      onUnknownChanged: widget.variant == TimePickerVariant.birth
          ? (value) => setState(() => _unknown = value)
          : null,
      unknownLabel: widget.variant == TimePickerVariant.birth ? '모름' : null,
      unknownNotice: '시간을 몰라도 괜찮아요.',
      sijinConfirm: widget.sijinConfirm,
    ),
  );
}

Widget _picker({
  TimePickerVariant variant = TimePickerVariant.birth,
  TimeOfDay value = const TimeOfDay(hour: 7, minute: 30),
  List<TimeOfDay>? changes,
  bool unknown = false,
  String? sijinConfirm,
}) => _Host(
  key: UniqueKey(),
  variant: variant,
  initial: value,
  changes: changes ?? [],
  unknown: unknown,
  sijinConfirm: sijinConfirm,
);

Wheel _wheel(WidgetTester tester, Key key) =>
    tester.widget<Wheel>(find.byKey(key));

void main() {
  group('time-picker', () {
    testWidgets('birth 분 휠은 0~59 모든 분입니다', (tester) async {
      await tester.pumpWidget(inputApp(_picker()));
      expect(_wheel(tester, TimePicker.minuteWheelKey).itemCount, 60);
    });

    testWidgets('notify 분 휠 값은 5의 배수뿐입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(_picker(variant: TimePickerVariant.notify)),
      );
      final minute = _wheel(tester, TimePicker.minuteWheelKey);
      expect(minute.itemCount, 12);
      for (var i = 0; i < minute.itemCount; i++) {
        final digits = RegExp(r'\d+')
            .firstMatch(minute.itemLabel(i))!
            .group(0)!;
        expect(int.parse(digits) % 5, 0, reason: minute.itemLabel(i));
      }
    });

    testWidgets('notify에는 모름 체크와 안내가 없습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(_picker(variant: TimePickerVariant.notify, unknown: true)),
      );
      expect(find.byType(CheckRow), findsNothing);
      expect(find.text('시간을 몰라도 괜찮아요.'), findsNothing);
    });

    testWidgets('오전·오후·시·분 값이 24시간 값으로 합쳐집니다', (tester) async {
      final changes = <TimeOfDay>[];
      await tester.pumpWidget(
        inputApp(
          _picker(
            value: const TimeOfDay(hour: 10, minute: 30),
            changes: changes,
          ),
        ),
      );
      // 시 휠 한 칸 아래로: 10시 → 11시.
      await tester.drag(
        find.byKey(TimePicker.hourWheelKey),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      expect(changes.last, const TimeOfDay(hour: 11, minute: 30));
      // 오전 → 오후.
      await tester.drag(
        find.byKey(TimePicker.meridiemWheelKey),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      expect(changes.last, const TimeOfDay(hour: 23, minute: 30));
    });

    testWidgets('오전 12시는 0시, 오후 12시는 12시로 합쳐집니다', (tester) async {
      Future<List<TimeOfDay>> turn(
        TimeOfDay start,
        Key wheel,
        double dy,
      ) async {
        final changes = <TimeOfDay>[];
        await tester.pumpWidget(
          inputApp(_picker(value: start, changes: changes)),
        );
        await tester.drag(find.byKey(wheel), Offset(0, dy));
        await tester.pumpAndSettle();
        return changes;
      }

      // 시 휠에서 1시 → 12시(이전 칸): 오전 1시 → 오전 12시(00:xx).
      expect(
        (await turn(
          const TimeOfDay(hour: 1, minute: 15),
          TimePicker.hourWheelKey,
          40,
        )).last,
        const TimeOfDay(hour: 0, minute: 15),
      );
      // 오후 1시 → 오후 12시(12:xx).
      expect(
        (await turn(
          const TimeOfDay(hour: 13, minute: 15),
          TimePicker.hourWheelKey,
          40,
        )).last,
        const TimeOfDay(hour: 12, minute: 15),
      );
      // 오전 12시(00:xx) → 오후 12시(12:xx), 다시 오전으로.
      expect(
        (await turn(
          const TimeOfDay(hour: 0, minute: 15),
          TimePicker.meridiemWheelKey,
          -40,
        )).last,
        const TimeOfDay(hour: 12, minute: 15),
      );
      expect(
        (await turn(
          const TimeOfDay(hour: 12, minute: 15),
          TimePicker.meridiemWheelKey,
          40,
        )).last,
        const TimeOfDay(hour: 0, minute: 15),
      );
      // 오전 12시에서 시 휠을 한 칸 올리면 오전 1시.
      expect(
        (await turn(
          const TimeOfDay(hour: 0, minute: 15),
          TimePicker.hourWheelKey,
          -40,
        )).last,
        const TimeOfDay(hour: 1, minute: 15),
      );
      // 오후 12시에서 시 휠을 한 칸 올리면 오후 1시.
      expect(
        (await turn(
          const TimeOfDay(hour: 12, minute: 15),
          TimePicker.hourWheelKey,
          -40,
        )).last,
        const TimeOfDay(hour: 13, minute: 15),
      );
    });

    testWidgets('notify 분 휠을 돌려 나가는 값은 늘 5의 배수입니다', (tester) async {
      final changes = <TimeOfDay>[];
      await tester.pumpWidget(
        inputApp(
          _picker(
            variant: TimePickerVariant.notify,
            value: const TimeOfDay(hour: 8, minute: 0),
            changes: changes,
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byKey(TimePicker.minuteWheelKey),
          const Offset(0, -40),
        );
        await tester.pumpAndSettle();
      }
      await tester.drag(
        find.byKey(TimePicker.hourWheelKey),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      expect(changes, isNotEmpty);
      expect(changes.every((time) => time.minute % 5 == 0), isTrue);
      expect(changes.last, const TimeOfDay(hour: 9, minute: 15));
    });

    testWidgets('notify에 5의 배수가 아닌 분을 주면 assert입니다', (tester) async {
      expect(
        () => TimePicker(
          variant: TimePickerVariant.notify,
          value: const TimeOfDay(hour: 8, minute: 3),
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('휠 한 칸마다 selection 햅틱 한 번', (tester) async {
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_picker()));
      await tester.drag(
        find.byKey(TimePicker.minuteWheelKey),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('unknown이면 휠이 비활성이고 안내가 보이며 시진 확인 글자가 없습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(_picker(unknown: true, sijinConfirm: '사시 (09:30~11:30)')),
      );
      await tester.pumpAndSettle();
      for (final key in [
        TimePicker.meridiemWheelKey,
        TimePicker.hourWheelKey,
        TimePicker.minuteWheelKey,
      ]) {
        expect(_wheel(tester, key).enabled, isFalse);
      }
      expect(find.text('시간을 몰라도 괜찮아요.'), findsOneWidget);
      expect(find.text('사시 (09:30~11:30)'), findsNothing);
    });

    testWidgets('unknown이면 휠 opacity 0.35에 blur 1.5입니다', (tester) async {
      await tester.pumpWidget(inputApp(_picker(unknown: true)));
      final opacity = tester.widget<Opacity>(
        find.byKey(TimePicker.wheelsDimKey),
      );
      expect(opacity.opacity, 0.35);
      expect(
        find.ancestor(
          of: find.byKey(TimePicker.wheelsDimKey),
          matching: find.byType(ImageFiltered),
        ),
        findsOneWidget,
      );
    });

    testWidgets('모름을 켜고 끄면 selection 햅틱이 나가고 휠이 깨어납니다', (tester) async {
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(inputApp(_picker()));
      await tester.tap(find.text('모름'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(_wheel(tester, TimePicker.hourWheelKey).enabled, isFalse);
      await tester.tap(find.text('모름'));
      await tester.pumpAndSettle();
      expect(_wheel(tester, TimePicker.hourWheelKey).enabled, isTrue);
    });

    testWidgets('비활성 휠은 끌어도 값이 바뀌지 않습니다', (tester) async {
      final changes = <TimeOfDay>[];
      await tester.pumpWidget(
        inputApp(_picker(unknown: true, changes: changes)),
      );
      await tester.drag(
        find.byKey(TimePicker.hourWheelKey),
        const Offset(0, -40),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });

    testWidgets('sijinConfirm이 있으면 보이고 null이면 자리가 없습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(_picker(sijinConfirm: '사시 (09:30~11:30)')),
      );
      await tester.pumpAndSettle();
      expect(find.text('사시 (09:30~11:30)'), findsOneWidget);
      final withConfirm = tester.getSize(find.byType(TimePicker)).height;

      await tester.pumpWidget(inputApp(_picker()));
      await tester.pumpAndSettle();
      expect(find.byKey(TimePicker.sijinConfirmKey), findsNothing);
      final without = tester.getSize(find.byType(TimePicker)).height;
      expect(without, lessThan(withConfirm));
      // 모름 체크 줄이 맨 아래라 그 아래에 빈 자리가 없습니다.
      expect(
        tester.getBottomLeft(find.byType(CheckRow)).dy,
        closeTo(tester.getBottomLeft(find.byType(TimePicker)).dy, 0.5),
      );
    });

    testWidgets('오전·오후·시·분 휠이 각각 adjustable Semantics입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_picker()));
      // 오전·오후는 칸이 둘뿐이라 끝 칸에서는 한쪽 동작만 있습니다.
      for (final (label, value, increase, decrease) in [
        ('오전 또는 오후', '오전', true, false),
        ('시', '7시', true, true),
        ('분', '30분', true, true),
      ]) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(
          data.hasAction(SemanticsAction.increase),
          increase,
          reason: label,
        );
        expect(
          data.hasAction(SemanticsAction.decrease),
          decrease,
          reason: label,
        );
        expect(data.value, value, reason: label);
      }
      handle.dispose();
    });

    testWidgets('unknown이면 휠 Semantics에 증가·감소 동작이 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_picker(unknown: true)));
      final data = tester
          .getSemantics(find.bySemanticsLabel('시'))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      handle.dispose();
    });

    testWidgets('휠 칸 높이는 40 이상이고 큰 글자에서 글자가 잘리지 않게 커집니다', (tester) async {
      await tester.pumpWidget(inputApp(_picker()));
      final normal = tester.getSize(find.byKey(TimePicker.wheelsKey)).height;
      expect(normal, 200);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: inputApp(_picker()),
        ),
      );
      expect(
        tester.getSize(find.byKey(TimePicker.wheelsKey)).height,
        greaterThan(normal),
      );
    });
  });
}
