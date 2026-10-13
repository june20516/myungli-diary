import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/licenses.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/fonts.dart';

/// lerp의 "다른 타입" 분기를 검사하려는 다른 ThemeExtension.
class _OtherExtension extends ThemeExtension<_OtherExtension> {
  const new();

  @override
  _OtherExtension copyWith() => this;

  @override
  _OtherExtension lerp(ThemeExtension<_OtherExtension>? other, double t) =>
      this;
}

/// `ThemeExtension<MyungliTokens>`를 따르지만 [MyungliTokens]가 아닌 확장.
/// lerp의 `is!` 분기(타입 검사를 통과한 다른 구현)를 검사합니다.
class _ForeignTokens extends ThemeExtension<MyungliTokens> {
  const new();

  @override
  ThemeExtension<MyungliTokens> copyWith() => this;

  @override
  ThemeExtension<MyungliTokens> lerp(
    ThemeExtension<MyungliTokens>? other,
    double t,
  ) => this;
}

const _light = MyungliTokens(
  colors: lightColors,
  typography: koType,
  gradients: lightGradients,
);
const _dark = MyungliTokens(
  colors: darkColors,
  typography: jaType,
  gradients: darkGradients,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('lerp는 other가 null이면 자기 자신을 돌려줍니다', () {
      expect(_light.lerp(null, 0.9), same(_light));
    });

    test('lerp에 다른 ThemeExtension을 주면 covariant 검사가 거부합니다', () {
      // other 타입은 ThemeExtension<MyungliTokens>로 좁혀져 있어 다른 확장은
      // 본문에 닿기 전에 TypeError입니다(ThemeData.lerp도 같은 키끼리만 호출).
      const dynamic erased = _light;

      expect(
        // ignore: avoid_dynamic_calls, 타입이 지워진 호출을 흉내냅니다.
        () => erased.lerp(const _OtherExtension(), 0.9),
        throwsA(isA<TypeError>()),
      );
    });

    test('lerp에 MyungliTokens가 아닌 같은 키의 확장을 주면 자기 자신입니다', () {
      expect(_light.lerp(const _ForeignTokens(), 0.9), same(_light));
    });

    test('lerp는 t가 0.5 미만이면 자기 자신, 이상이면 other입니다', () {
      expect(_light.lerp(_dark, 0.49), same(_light));
      expect(_light.lerp(_dark, 0.5), same(_dark));
    });

    test('copyWith는 바꾼 필드만 반영합니다', () {
      final changed = _light.copyWith(typography: jaType);

      expect(changed.typography, jaType);
      expect(changed.colors, _light.colors);
      expect(changed.gradients, _light.gradients);
      expect(_light.copyWith().typography, koType);
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
    // 줄 전체 일치: `Pretendard`가 `Pretendard JP` 줄에 걸리지 않게 합니다.
    final declared = RegExp(
      r'^\s*- family: (.+)$',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)!.trim()).toSet();

    expect(declared, families);
    expect({for (final f in bundledFonts) f.family}, families);
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

  test('글꼴 목록의 라이선스 파일이 pubspec assets에 선언돼 있습니다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final font in bundledFonts) {
      for (final file in font.licenseFiles) {
        expect(
          pubspec,
          contains('    - assets/fonts/${font.folder}/$file\n'),
          reason: '${font.folder}/$file',
        );
      }
    }
  });

  test('registerFontLicenses는 네 글꼴의 라이선스 본문을 더합니다', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();

    for (final font in bundledFonts) {
      final entry = entries.where((e) => e.packages.contains(font.family));
      expect(entry, hasLength(1), reason: font.family);
      final text = entry.single.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL OPEN FONT LICENSE'), reason: font.family);
    }
  });

  test('loadBundledFonts 뒤에는 테스트 기본 글꼴(Ahem)과 다른 폭으로 그려집니다', () async {
    const sample = '명리일기 Hello 123';
    double widthOf(String family) {
      final painter = TextPainter(
        text: TextSpan(
          text: sample,
          style: TextStyle(fontFamily: family),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    final fallbackWidth = widthOf('NoSuchFamily');
    await loadBundledFonts();

    for (final font in bundledFonts) {
      expect(widthOf(font.family), isNot(fallbackWidth), reason: font.family);
    }
  });
}
