import 'dart:ui' show CheckedState, SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
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

const AppGlyph _bell = AppGlyph(
  light: PhosphorIconsLight.bell,
  regular: PhosphorIconsRegular.bell,
);

const AppGlyph _trash = AppGlyph(
  light: PhosphorIconsLight.trash,
  regular: PhosphorIconsRegular.trash,
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

    testWidgets('destructive: 경고 표시 없이 자기 아이콘(Regular)과 600 글자, 화살표 없음', (
      tester,
    ) async {
      await tester.pumpWidget(
        inputApp(
          SettingsRow(
            variant: SettingsRowVariant.destructive,
            label: '알림 시각',
            leading: _trash,
            onTap: () {},
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AppIcon && w.icon.light == PhosphorIconsFill.warningCircle,
        ),
        findsNothing,
      );
      final leading = tester.widget<AppIcon>(
        find.byKey(SettingsRow.leadingKey),
      );
      expect(leading.weight, AppIconWeight.regular);
      expect(find.byKey(SettingsRow.chevronKey), findsNothing);
      expect(
        tester.widget<Text>(find.text('알림 시각')).style?.fontWeight,
        FontWeight.w600,
      );
    });

    testWidgets('leading: 20 Light 고정(글자 배율 무시), 글자와 사이 12', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: inputApp(
            SettingsRow(
              variant: SettingsRowVariant.navigate,
              label: '알림 시각',
              leading: _bell,
              onTap: () {},
            ),
          ),
        ),
      );
      final leading = tester.widget<AppIcon>(
        find.byKey(SettingsRow.leadingKey),
      );
      expect(leading.weight, AppIconWeight.light);
      expect(leading.scalesWithText, isFalse);
      final iconRect = tester.getRect(find.byKey(SettingsRow.leadingKey));
      expect(iconRect.size, const Size.square(20));
      expect(tester.getRect(find.text('알림 시각')).left - iconRect.right, 12);
    });

    testWidgets('select: 꺾쇠 없이 고른 줄 끝에만 체크(Regular 20), 라디오로 읽습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(
          Column(
            children: [
              SettingsRow(
                variant: SettingsRowVariant.select,
                label: '한국어',
                selected: true,
                onTap: () {},
              ),
              SettingsRow(
                variant: SettingsRowVariant.select,
                label: 'English',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(SettingsRow.chevronKey), findsNothing);
      expect(find.byKey(SettingsRow.checkKey), findsOneWidget);
      final context = tester.element(find.byType(Column).first);
      final check = tester.widget<AppIcon>(find.byKey(SettingsRow.checkKey));
      expect(check.weight, AppIconWeight.regular);
      expect(check.size, AppIconSize.s20);
      expect(check.color, context.tokens.colors.actionPrimary);
      final checked = tester
          .getSemantics(find.bySemanticsLabel('한국어'))
          .getSemanticsData();
      expect(checked.flagsCollection.isChecked, CheckedState.isTrue);
      expect(checked.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(checked.flagsCollection.isButton, isFalse);
      final other = tester
          .getSemantics(find.bySemanticsLabel('English'))
          .getSemanticsData();
      expect(other.flagsCollection.isChecked, CheckedState.isFalse);
      handle.dispose();
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

  group('settings-row readonly (V122)', () {
    // 기본 테스트 화면 폭 800: 줄 안쪽 폭은 좌우 16을 뺀 768, 값은 그 절반 384까지입니다.
    const surfaceWidth = 800.0;
    const innerWidth = surfaceWidth - SettingsRow.paddingX * 2;

    Widget readonly(String label, String? value, {String? identifier}) =>
        SettingsRow(
          variant: SettingsRowVariant.readonly,
          label: label,
          value: value,
          identifier: identifier,
        );

    testWidgets('이름 왼쪽 text.primary, 값 오른쪽 text.secondary, 꺾쇠와 눌림 없음', (
      tester,
    ) async {
      await tester.pumpWidget(inputApp(readonly('호칭', '별님')));
      final colors = tester.element(find.byType(SettingsRow)).tokens.colors;
      // 누를 수 없어도 disabled가 아니라 본문색입니다.
      expect(
        tester.widget<Text>(find.text('호칭')).style?.color,
        colors.textPrimary,
      );
      final value = tester.widget<Text>(find.text('별님'));
      expect(value.style?.color, colors.textSecondary);
      expect(value.textAlign, TextAlign.end);
      expect(tester.getTopLeft(find.text('호칭')).dx, SettingsRow.paddingX);
      expect(
        tester.getTopRight(find.text('별님')).dx,
        surfaceWidth - SettingsRow.paddingX,
      );
      expect(find.byKey(SettingsRow.chevronKey), findsNothing);
      expect(find.byType(PressInkTarget), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(
        tester.getSize(find.byType(SettingsRow)).height,
        greaterThanOrEqualTo(SettingsRow.minHeight),
      );
    });

    testWidgets('스크린리더는 버튼이 아닌 글자로 이름 다음 값을 읽고 누를 수 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(readonly('호칭', '별님', identifier: 'x.input')),
      );
      final node = find.bySemanticsIdentifier('x.input');
      expect(node, findsOneWidget);
      final data = tester.getSemantics(node).getSemanticsData();
      expect(data.label, '호칭, 별님');
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      // 이름과 값을 따로 읽지 않습니다.
      expect(find.bySemanticsLabel('호칭'), findsNothing);
      handle.dispose();
    });

    testWidgets('긴 값은 줄 안쪽 폭의 절반까지 쓰고 오른쪽 맞춤으로 줄을 바꿉니다', (tester) async {
      const long = '로스앤젤레스 카운티 서쪽 끝 바닷가 마을 산타모니카 해변 근처, 미국 캘리포니아';
      await tester.pumpWidget(inputApp(readonly('출생지', long)));
      final rect = tester.getRect(find.text(long));
      expect(rect.width, lessThanOrEqualTo(innerWidth / 2));
      expect(rect.right, surfaceWidth - SettingsRow.paddingX);
      final lineHeight = tester.getSize(find.text('출생지')).height;
      expect(rect.height, greaterThan(lineHeight));
      // 이름은 줄을 바꾸지 않고 왼쪽에 그대로입니다.
      expect(tester.getTopLeft(find.text('출생지')).dx, SettingsRow.paddingX);
    });

    testWidgets('큰 글자에서도 값은 절반까지, 줄은 함께 커집니다', (tester) async {
      await tester.pumpWidget(inputApp(readonly('생일', '양력 1990년 3월 15일')));
      final base = tester.getSize(find.byType(SettingsRow)).height;
      await tester.pumpWidget(
        inputApp(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: readonly('생일', '양력 1990년 3월 15일'),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(SettingsRow)).height,
        greaterThan(base),
      );
      expect(
        tester.getSize(find.text('양력 1990년 3월 15일')).width,
        lessThanOrEqualTo(innerWidth / 2),
      );
    });

    testWidgets('값이 비었으면 이름만 그리고 이름만 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      for (final value in [null, '']) {
        await tester.pumpWidget(
          inputApp(readonly('호칭', value, identifier: 'x.input')),
        );
        expect(find.byType(Text), findsOneWidget, reason: '$value');
        expect(
          tester
              .getSemantics(find.bySemanticsIdentifier('x.input'))
              .getSemanticsData()
              .label,
          '호칭',
          reason: '$value',
        );
      }
      handle.dispose();
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
      expect(find.byType(ListDivider), findsNWidgets(2));
      expect(tester.getSize(find.byType(ListDivider).first).height, 0.5);
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
