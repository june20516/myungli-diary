import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/button_pair.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/elements/highlight_current.dart';
import 'package:myungli_diary/design/elements/keyboard_dismiss.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/elements/stem_chip.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) => MaterialApp(
  theme: buildTheme(brightness: brightness, locale: const Locale('ko')),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ko'),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: home!,
  ),
  home: Scaffold(resizeToAvoidBottomInset: false, body: child),
);

/// 기기 키보드 inset을 높이 [height]로 주입합니다(View 값).
void _showKeyboard(WidgetTester tester, [double height = 300]) {
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final l10n = AppLocalizationsKo();

  group('list.divider', () {
    testWidgets('높이 0.5, 색 line, 좌우 들임 16과 16', (tester) async {
      await tester.pumpWidget(_app(const Center(child: ListDivider())));
      final screen = tester.getRect(find.byType(Scaffold));
      final rect = tester.getRect(find.byType(ListDivider));
      expect(rect.height, BorderTokens.hairline);
      expect(BorderTokens.hairline, 0.5);
      final line = tester.getRect(
        find.descendant(
          of: find.byType(ListDivider),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(line.left - screen.left, 16);
      expect(screen.right - line.right, 16);
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ListDivider),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(
        box.color,
        tester.element(find.byType(ListDivider)).tokens.colors.line,
      );
    });

    testWidgets('들임을 바꿀 수 있습니다', (tester) async {
      await tester.pumpWidget(
        _app(const Center(child: ListDivider(indentStart: 0, indentEnd: 8))),
      );
      final screen = tester.getRect(find.byType(Scaffold));
      final line = tester.getRect(
        find.descendant(
          of: find.byType(ListDivider),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(line.left - screen.left, 0);
      expect(screen.right - line.right, 8);
    });
  });

  group('list.divider inSheet', () {
    testWidgets('시트 본문에 바로 놓인 목록은 들임 0으로 본문 폭 그대로입니다(V124)', (tester) async {
      await tester.pumpWidget(_app(const Center(child: ListDivider.inSheet())));
      final screen = tester.getRect(find.byType(Scaffold));
      final line = tester.getRect(
        find.descendant(
          of: find.byType(ListDivider),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(line.left, screen.left);
      expect(line.right, screen.right);
      expect(line.height, BorderTokens.hairline);
    });
  });

  group('button.pair', () {
    testWidgets('filled가 위, quiet가 아래, 사이 8', (tester) async {
      await tester.pumpWidget(
        _app(
          ButtonPair(
            filled: PrimaryButton(label: '저장', onPressed: () {}),
            quiet: PrimaryButton(
              label: '건너뛰기',
              onPressed: () {},
              variant: PrimaryButtonVariant.quiet,
            ),
          ),
        ),
      );
      final top = tester.getRect(find.byKey(PrimaryButton.faceKey).first);
      final bottom = tester.getRect(find.byKey(PrimaryButton.faceKey).last);
      expect(find.text('저장'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('저장')).dy,
        lessThan(tester.getTopLeft(find.text('건너뛰기')).dy),
      );
      expect(bottom.top - top.bottom, 8);
      // 높이는 PrimaryButton 변형 그대로(quiet 52는 Task 5에서 바뀝니다).
      expect(top.height, PrimaryButtonVariant.filled.height);
      expect(bottom.height, PrimaryButtonVariant.quiet.height);
      // 너비는 채웁니다.
      expect(top.width, tester.getSize(find.byType(ButtonPair)).width);
    });
  });

  group('keyboard.dismiss', () {
    Widget overlay(FocusNode focus) => _app(
      KeyboardDismissOverlay(
        focus: focus,
        child: Center(child: TextField(focusNode: focus)),
      ),
    );

    testWidgets('초점이 없으면 키보드가 있어도 안 보입니다', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      _showKeyboard(tester);
      await tester.pumpWidget(overlay(focus));
      expect(find.bySemanticsLabel(l10n.keyboardDismiss), findsNothing);
      expect(find.byType(KeyboardDismissButton), findsNothing);
    });

    testWidgets('초점이 있어도 키보드가 없으면 안 보입니다', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(overlay(focus));
      focus.requestFocus();
      await tester.pump();
      expect(find.byType(KeyboardDismissButton), findsNothing);
    });

    testWidgets('키보드와 초점이 있으면 보이고, 누르면 초점이 풀립니다', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      _showKeyboard(tester);
      await tester.pumpWidget(overlay(focus));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(find.bySemanticsLabel(l10n.keyboardDismiss), findsOneWidget);

      await tester.tap(find.byType(KeyboardDismissButton));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(find.byType(KeyboardDismissButton), findsNothing);
    });

    testWidgets('44 원형, 키보드 inset 위 12, 오른쪽 20, bg.sheet와 shadow.raised', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      _showKeyboard(tester);
      await tester.pumpWidget(overlay(focus));
      focus.requestFocus();
      await tester.pump();
      final screen = tester.getRect(find.byType(Scaffold));
      final rect = tester.getRect(find.byType(KeyboardDismissButton));
      expect(rect.size, const Size(44, 44));
      expect(screen.bottom - 300 - rect.bottom, 12);
      expect(screen.right - rect.right, 20);
      final tokens = tester.element(find.byType(KeyboardDismissButton)).tokens;
      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(KeyboardDismissButton),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, tokens.colors.bgSheet);
      expect(decoration.boxShadow, Shadows.raised);
    });

    testWidgets('글자 배율 2.0에서도 아이콘은 20, 버튼은 44입니다', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      _showKeyboard(tester);
      await tester.pumpWidget(
        _app(
          textScale: 2,
          KeyboardDismissOverlay(
            focus: focus,
            child: Center(child: TextField(focusNode: focus)),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(
        tester.getSize(find.byType(KeyboardDismissButton)),
        const Size(44, 44),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(KeyboardDismissButton),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.size, 20);
    });
  });

  group('stem.chip', () {
    testWidgets('22 칸, ohaeng.cell 색, 한자 13 700', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: StemChip(element: FiveElement.fire, hanja: '丙'),
          ),
        ),
      );
      expect(tester.getSize(find.byType(StemChip)), const Size(22, 22));
      final tokens = tester.element(find.byType(StemChip)).tokens;
      final cell = ohaengCellColorsOf(tokens.colors, FiveElement.fire);
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(StemChip),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, cell.bg);
      expect(decoration.borderRadius, BorderRadius.circular(Radii.sm));
      final text = tester.widget<Text>(find.text('丙'));
      expect(text.style!.color, cell.fg);
      expect(text.style!.fontSize, 13);
      expect(text.style!.fontWeight, FontWeight.w700);
      expect(text.style!.fontFamily, tokens.typography.hanjaPillar.fontFamily);
    });

    testWidgets('오행마다 색이 다릅니다', (tester) async {
      await tester.pumpWidget(
        _app(
          Row(
            children: [
              for (final e in FiveElement.values)
                StemChip(element: e, hanja: '甲'),
            ],
          ),
        ),
      );
      final colors = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(StemChip),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toSet();
      expect(colors.length, FiveElement.values.length);
    });

    testWidgets('글자 배율 2.0에서도 칸은 22, 글자는 1.3배에서 멈춥니다', (tester) async {
      await tester.pumpWidget(
        _app(
          textScale: 2,
          const Center(
            child: StemChip(element: FiveElement.wood, hanja: '甲'),
          ),
        ),
      );
      expect(tester.getSize(find.byType(StemChip)), const Size(22, 22));
      final paragraph = tester.renderObject<RenderBox>(find.text('甲'));
      expect(paragraph.size.height, lessThanOrEqualTo(13 * 1.3 + 1));
    });
  });

  group('highlight.current', () {
    Color? bgOf(WidgetTester tester) => tester
        .widget<ColoredBox>(
          find.descendant(
            of: find.byType(HighlightCurrent),
            matching: find.byType(ColoredBox),
          ),
        )
        .color;

    testWidgets('color.highlight.bg로 칠합니다', (tester) async {
      await tester.pumpWidget(
        _app(const HighlightCurrent(child: SizedBox(height: 10, width: 10))),
      );
      expect(
        bgOf(tester),
        tester.element(find.byType(HighlightCurrent)).tokens.colors.highlightBg,
      );
    });

    testWidgets('다크 테마의 바탕은 라이트와 다릅니다', (tester) async {
      const child = HighlightCurrent(child: SizedBox(height: 10, width: 10));
      await tester.pumpWidget(_app(child));
      final light = bgOf(tester);
      await tester.pumpWidget(_app(child, brightness: Brightness.dark));
      await tester.pumpAndSettle(); // 테마 전환 애니메이션
      final dark = bgOf(tester);
      expect(dark, isNot(light));
    });
  });

  group('keyboard.dismiss Scaffold 안과 바깥', () {
    Widget scaffoldApp(
      FocusNode focus, {
      required bool resize,
      required bool inside,
    }) {
      final field = Center(child: TextField(focusNode: focus));
      return MaterialApp(
        theme: buildTheme(
          brightness: Brightness.light,
          locale: const Locale('ko'),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: inside
            ? Scaffold(
                resizeToAvoidBottomInset: resize,
                body: KeyboardDismissOverlay(focus: focus, child: field),
              )
            : KeyboardDismissOverlay(
                focus: focus,
                child: Scaffold(resizeToAvoidBottomInset: resize, body: field),
              ),
      );
    }

    for (final inside in [true, false]) {
      for (final resize in [true, false]) {
        testWidgets('${inside ? "Scaffold body 안" : "Scaffold 바깥"}, '
            'resizeToAvoidBottomInset $resize: 키보드 위 12에 뜹니다', (tester) async {
          final focus = FocusNode();
          addTearDown(focus.dispose);
          _showKeyboard(tester);
          await tester.pumpWidget(
            scaffoldApp(focus, resize: resize, inside: inside),
          );
          focus.requestFocus();
          await tester.pump();
          final rect = tester.getRect(find.byType(KeyboardDismissButton));
          final screenBottom = tester.view.physicalSize.height;
          expect(screenBottom - 300 - rect.bottom, 12);
        });
      }
    }
  });
}
