import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _heart = AppGlyph(
  light: PhosphorIconsLight.heart,
  regular: PhosphorIconsRegular.heart,
);

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: home!,
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppIconSize.adjacentText', () {
    test('글자 크기 구간마다 16, 20, 24, 28 단계를 고릅니다', () {
      expect(AppIconSize.adjacentText(14), AppIconSize.s16);
      expect(AppIconSize.adjacentText(15), AppIconSize.s20);
      expect(AppIconSize.adjacentText(18), AppIconSize.s20);
      expect(AppIconSize.adjacentText(19), AppIconSize.s24);
      expect(AppIconSize.adjacentText(22), AppIconSize.s24);
      expect(AppIconSize.adjacentText(23), AppIconSize.s28);
      expect(AppIconSize.adjacentText(14.5), AppIconSize.s20);
      expect(AppIconSize.adjacentText(18.5), AppIconSize.s24);
      expect(AppIconSize.adjacentText(22.5), AppIconSize.s28);
    });
  });

  group('AppIcon.weightFor', () {
    test('400~500 옆은 light, 600 이상 옆은 regular입니다', () {
      expect(AppIcon.weightFor(FontWeight.w400), AppIconWeight.light);
      expect(AppIcon.weightFor(FontWeight.w500), AppIconWeight.light);
      expect(AppIcon.weightFor(FontWeight.w600), AppIconWeight.regular);
      expect(AppIcon.weightFor(FontWeight.w700), AppIconWeight.regular);
    });
  });

  group('AppIcon 글자 배율', () {
    double drawnSize(WidgetTester tester) =>
        tester.widget<Icon>(find.byType(Icon)).size!;

    testWidgets('scalesWithText 없이는 글자 배율 2.0에서도 20입니다', (tester) async {
      await tester.pumpWidget(
        _app(const AppIcon(_heart, size: AppIconSize.s20), textScale: 2),
      );
      expect(drawnSize(tester), 20);
    });

    testWidgets('scalesWithText는 배율을 textScaleMax까지 곱합니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const AppIcon(
            _heart,
            size: AppIconSize.s20,
            scalesWithText: true,
            textScaleMax: 1.3,
          ),
          textScale: 2,
        ),
      );
      expect(drawnSize(tester), closeTo(26, 0.001));
    });

    testWidgets('textScaleMax보다 작은 배율은 그대로 곱합니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const AppIcon(
            _heart,
            size: AppIconSize.s20,
            scalesWithText: true,
            textScaleMax: 1.3,
          ),
          textScale: 1.1,
        ),
      );
      expect(drawnSize(tester), closeTo(22, 0.001));
    });

    testWidgets('caution 자동 크기는 배율을 곱하고 textScaleMax에서 멈춥니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const DefaultTextStyle(
            style: TextStyle(fontSize: 14),
            child: AppIcon.caution(textScaleMax: 1.3),
          ),
          textScale: 2,
        ),
      );
      expect(drawnSize(tester), closeTo(16 * 1.3, 0.001));
    });

    testWidgets('caution은 크기를 고정하면 배율을 따르지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(const AppIcon.caution(size: AppIconSize.s20), textScale: 2),
      );
      expect(drawnSize(tester), 20);
    });
  });
}
