import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

void main() {
  group('buildTheme', () {
    test('ja 다크는 darkColors와 jaType(Zen Maru Gothic)을 씁니다', () {
      final theme = buildTheme(
        brightness: Brightness.dark,
        locale: const Locale('ja'),
      );
      final tokens = theme.extension<MyungliTokens>()!;

      expect(tokens.colors, darkColors);
      expect(tokens.typography, jaType);
      expect(tokens.typography.sentenceCard.fontFamily, 'Zen Maru Gothic');
    });

    test('en은 koType을 쓰고 라이트는 lightColors입니다', () {
      final theme = buildTheme(
        brightness: Brightness.light,
        locale: const Locale('en'),
      );
      final tokens = theme.extension<MyungliTokens>()!;

      expect(tokens.typography, koType);
      expect(tokens.colors, lightColors);
      expect(tokens.gradients, lightGradients);
    });

    test('Material 기본 효과를 끕니다', () {
      final theme = buildTheme(
        brightness: Brightness.light,
        locale: const Locale('ko'),
      );

      expect(theme.useMaterial3, isTrue);
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.highlightColor, Colors.transparent);
      expect(theme.hoverColor, Colors.transparent);
      expect(theme.focusColor, Colors.transparent);
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
    });

    test('lerp는 같은 값을 돌려줍니다', () {
      const tokens = MyungliTokens(
        colors: lightColors,
        typography: koType,
        gradients: lightGradients,
      );

      expect(tokens.lerp(null, 0.5), same(tokens));
      expect(tokens.copyWith(), isA<MyungliTokens>());
    });
  });

  test('토큰의 fontFamily 첫 값이 모두 pubspec.yaml에 있습니다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final styles = [
      for (final t in [koType, jaType]) ...[
        t.sentenceCard,
        t.sentenceBody,
        t.display,
        t.title,
        t.subtitle,
        t.labelLg,
        t.labelMd,
        t.captionMd,
        t.captionSm,
        t.captionLg,
        t.numericCalendar,
        t.numericTable,
        t.hanjaPillar,
        t.bodyUi,
      ],
    ];
    final families = {for (final s in styles) s.fontFamily!};

    expect(families, {
      'Gowun Dodum',
      'Zen Maru Gothic',
      'Pretendard',
      'Pretendard JP',
    });
    for (final family in families) {
      expect(pubspec, contains('- family: $family'));
    }
  });

  test('pubspec.yaml이 선언한 글꼴·라이선스 파일이 모두 있습니다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = RegExp(
      r'(?:- asset:|^\s+-) (assets/fonts/\S+)',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)!).toList();

    expect(assets, isNotEmpty);
    for (final path in assets) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
