import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../input/input_harness.dart';

Widget _row(
  SettingsRowVariant variant, {
  String? value,
  bool toggled = false,
  VoidCallback? onTap,
  ValueChanged<bool>? onToggle,
}) => SettingsRow(
  variant: variant,
  label: '알림 시각',
  value: value,
  toggled: toggled,
  onTap: onTap,
  onToggle: onToggle,
);

Color? _labelColor(WidgetTester tester) =>
    tester.widget<Text>(find.text('알림 시각')).style?.color;

void main() {
  group('settings-row', () {
    testWidgets('navigate: 화살표가 있고 누르면 onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        inputApp(_row(SettingsRowVariant.navigate, onTap: () => taps++)),
      );
      expect(find.byKey(SettingsRow.chevronKey), findsOneWidget);
      expect(find.byKey(SettingsRow.toggleKey), findsNothing);
      await tester.tap(find.byType(SettingsRow));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('value: 값 글자(text.secondary)와 화살표, 라벨은 "글자, 값"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(_row(SettingsRowVariant.value, value: '08:00', onTap: () {})),
      );
      final context = tester.element(find.byType(SettingsRow));
      expect(
        tester.widget<Text>(find.text('08:00')).style?.color,
        context.tokens.colors.textSecondary,
      );
      expect(find.byKey(SettingsRow.chevronKey), findsOneWidget);
      // 값은 화살표 바로 앞, 오른쪽 끝에 붙습니다.
      expect(
        tester.getTopRight(find.text('08:00')).dx,
        closeTo(tester.getTopLeft(find.byKey(SettingsRow.chevronKey)).dx, 8),
      );
      expect(find.bySemanticsLabel('알림 시각, 08:00'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('value 글자는 다른 변형에서 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          _row(SettingsRowVariant.navigate, value: '08:00', onTap: () {}),
        ),
      );
      expect(find.text('08:00'), findsNothing);
    });

    testWidgets('toggle: 스위치로 읽고 누르면 반대 값과 selection 햅틱 한 번', (tester) async {
      final handle = tester.ensureSemantics();
      final haptics = recordHaptics(tester);
      final values = <bool>[];
      await tester.pumpWidget(
        inputApp(_row(SettingsRowVariant.toggle, onToggle: values.add)),
      );
      expect(find.byKey(SettingsRow.chevronKey), findsNothing);
      expect(find.byKey(SettingsRow.toggleKey), findsOneWidget);
      final data = tester
          .getSemantics(find.bySemanticsLabel('알림 시각'))
          .getSemanticsData();
      expect(data.flagsCollection.isToggled, isNotNull);
      await tester.tap(find.byType(SettingsRow));
      await tester.pumpAndSettle();
      expect(values, [true]);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      handle.dispose();
    });

    testWidgets('destructive: 경고 표시와 굵은 글자, 화살표 없음', (tester) async {
      await tester.pumpWidget(
        inputApp(_row(SettingsRowVariant.destructive, onTap: () {})),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AppIcon && w.icon.light == PhosphorIconsFill.warningCircle,
        ),
        findsOneWidget,
      );
      expect(find.byKey(SettingsRow.chevronKey), findsNothing);
      expect(
        tester.widget<Text>(find.text('알림 시각')).style?.fontWeight,
        FontWeight.w600,
      );
    });

    testWidgets('disabled: 글자 disabled.fg, 눌러도 아무 일 없음', (tester) async {
      await tester.pumpWidget(inputApp(_row(SettingsRowVariant.navigate)));
      final context = tester.element(find.byType(SettingsRow));
      expect(_labelColor(tester), context.tokens.colors.disabledFg);
      await tester.pumpWidget(inputApp(_row(SettingsRowVariant.toggle)));
      await tester.tap(find.byType(SettingsRow));
      await tester.pumpAndSettle();
    });

    testWidgets('줄 높이는 52 이상, 글자가 커지면 함께 커집니다', (tester) async {
      await tester.pumpWidget(
        inputApp(_row(SettingsRowVariant.navigate, onTap: () {})),
      );
      final base = tester.getSize(find.byType(SettingsRow)).height;
      expect(base, greaterThanOrEqualTo(SettingsRow.minHeight));
      await tester.pumpWidget(
        inputApp(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _row(SettingsRowVariant.navigate, onTap: () {}),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(SettingsRow)).height,
        greaterThan(base),
      );
    });
  });

  group('settings group', () {
    testWidgets('줄 사이에만 1px 선, 묶음 제목은 머리글로 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          SettingsGroup(
            title: '계정',
            children: [
              _row(SettingsRowVariant.navigate, onTap: () {}),
              _row(SettingsRowVariant.destructive, onTap: () {}),
              _row(SettingsRowVariant.destructive, onTap: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(SettingsGroupDivider), findsNWidgets(2));
      expect(tester.getSize(find.byType(SettingsGroupDivider).first).height, 1);
      expect(
        tester
            .getSemantics(find.text('계정'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('묶음 안내는 카드 위에 두 줄까지, 슬롯 id로 찾습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          SettingsGroup(
            note: '바꾸면 사주를 다시 계산해요. ' * 10,
            noteIdentifier: 'x.notice',
            children: [_row(SettingsRowVariant.navigate, onTap: () {})],
          ),
        ),
      );
      final note = find.byKey(const ValueKey('x.notice'));
      expect(tester.widget<Text>(note).maxLines, SettingsGroup.noteMaxLines);
      expect(
        tester.getBottomLeft(note).dy,
        lessThan(tester.getTopLeft(find.byType(SettingsRow)).dy),
      );
      expect(find.bySemanticsIdentifier('x.notice'), findsOneWidget);
      handle.dispose();
    });
  });
}
