import 'dart:convert';
import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/tokens/css_gradient.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../../tool/common/dart_format.dart';
import '../../tool/gen_tokens.dart';
import '../../tool/tokens/dtcg.dart';

/// 생성 소스의 `Color(0xFF…)`·`Color.from(…)` 표기를 hex와 alpha로 읽습니다.
({String hex, double alpha}) _parseColorSource(String text) {
  final opaque = RegExp(r'^Color\(0xFF([0-9A-F]{6})\)$').firstMatch(text);
  if (opaque != null) {
    return (hex: '#${opaque.group(1)!.toLowerCase()}', alpha: 1);
  }
  final m = RegExp(
    r'alpha:\s*([\d.]+),\s*red:\s*0x([0-9a-f]{2}) / 255,\s*'
    r'green:\s*0x([0-9a-f]{2}) / 255,\s*blue:\s*0x([0-9a-f]{2}) / 255',
  ).firstMatch(text)!;
  return (
    hex: '#${m.group(2)}${m.group(3)}${m.group(4)}',
    alpha: double.parse(m.group(1)!),
  );
}

const _tokenDir = '../docs/identity/design/tokens';

Map<String, Object?> _readTokenFile(String name) =>
    jsonDecode(File('$_tokenDir/$name').readAsStringSync())
        as Map<String, Object?>;

Map<String, ResolvedToken> _theme(String mode, String typography) =>
    resolveTheme([
      _readTokenFile('primitive.tokens.json'),
      _readTokenFile('color.$mode.tokens.json'),
      _readTokenFile(typography),
    ]);

void main() {
  group('resolveTheme', () {
    late Map<String, ResolvedToken> light;
    late Map<String, ResolvedToken> dark;

    setUp(() {
      light = _theme('light', 'typography.tokens.json');
      dark = _theme('dark', 'typography.tokens.json');
    });

    test('참조를 풀어 color.seal.fill이 color.action.primary와 같은 hex가 된다', () {
      for (final theme in [light, dark]) {
        final fill = parseColor(theme['color.seal.fill']!.value);
        final primary = parseColor(theme['color.action.primary']!.value);
        expect(fill.hex, primary.hex);
      }
    });

    test('참조 체인(status → term → 원시 팔레트)도 푼다', () {
      final status = parseColor(light['color.status.bg']!.value);
      final term = parseColor(light['color.term.bg']!.value);
      expect(status.hex, term.hex);
    });

    test('알파가 보존된다', () {
      double alpha(Map<String, ResolvedToken> t, String name) =>
          parseColor(t[name]!.value).alpha;
      expect(alpha(light, 'color.chip.bg'), 0.70);
      expect(alpha(dark, 'color.chip.bg'), 0.08);
      expect(alpha(light, 'color.scrim'), 0.32);
      expect(alpha(dark, 'color.scrim'), 0.50);
      expect(alpha(light, 'color.bg.base'), 1);
    });

    test('짝 파일의 토큰 이름 집합이 같다', () {
      expect(dark.keys.toSet(), light.keys.toSet());
      final ja = _theme('light', 'typography.ja.tokens.json');
      expect(ja.keys.toSet(), light.keys.toSet());
    });

    test('typography 안의 fontFamily 참조가 목록으로 풀린다', () {
      final card = light['type.sentence.card']!.value! as Map<String, Object?>;
      expect(card['fontFamily'], ['Gowun Dodum', 'Pretendard', 'sans-serif']);
    });

    test('깨진 참조는 TokenError', () {
      expect(
        () => resolveTheme([
          {
            'color': {
              'a': {r'$type': 'color', r'$value': '{color.missing}'},
            },
          },
        ]),
        throwsA(isA<TokenError>()),
      );
    });

    test('순환 참조는 TokenError', () {
      expect(
        () => resolveTheme([
          {
            'color': {
              'a': {r'$type': 'color', r'$value': '{color.b}'},
              'b': {r'$type': 'color', r'$value': '{color.a}'},
            },
          },
        ]),
        throwsA(isA<TokenError>()),
      );
    });

    test('파일 사이에 같은 이름이 중복되면 TokenError', () {
      final token = {r'$type': 'dimension', r'$value': 1};
      expect(
        () => resolveTheme([
          {
            'space': {'a': token},
          },
          {
            'space': {'a': token},
          },
        ]),
        throwsA(isA<TokenError>()),
      );
    });
  });

  group('generateTokensSource', () {
    late TokenThemes themes;
    late String source;

    setUp(() {
      themes = loadThemes(_tokenDir);
      source = generateTokensSource(themes);
    });

    test('첫 줄이 생성 안내다', () {
      expect(
        source.split('\n').first,
        '// 생성 코드: dart run tool/gen_tokens.dart. 손으로 고치지 않습니다.',
      );
    });

    test('원시 팔레트 이름이 식별자(필드·상수)로 나오지 않는다', () {
      final identifiers = [
        ...RegExp(
          r'^\s*final \w+ (\w+);',
          multiLine: true,
        ).allMatches(source).map((m) => m.group(1)!),
        ...RegExp(
          r'^\s*(?:static )?const (?:[\w<>]+ )?(\w+) =',
          multiLine: true,
        ).allMatches(source).map((m) => m.group(1)!),
        ...RegExp(
          r'^\s*(?:abstract )?final class (\w+)',
          multiLine: true,
        ).allMatches(source).map((m) => m.group(1)!),
      ];
      expect(identifiers.length, greaterThan(100));
      for (final id in identifiers) {
        expect(
          id,
          isNot(
            matches(
              RegExp('^(sage|coral|neutral|white)', caseSensitive: false),
            ),
          ),
        );
      }
    });

    test('모든 색 역할이 4 테마의 해석된 hex·alpha와 같다', () {
      for (final (constName, theme) in [
        ('lightColors', themes.lightKo),
        ('darkColors', themes.darkKo),
        ('lightColors', themes.lightJa),
      ]) {
        final block = RegExp(
          'const $constName = ColorTokens\\((.*?)\\n\\);',
          dotAll: true,
        ).firstMatch(source)!.group(1)!;
        final generated = {
          for (final m in RegExp(
            r'(\w+):\s*(Color(?:\.from)?\([^)]*\))',
          ).allMatches(block))
            m.group(1)!: m.group(2)!,
        };
        final roles = theme.keys.where(
          (n) =>
              n.startsWith('color.') &&
              !RegExp(r'^color\.(sage|coral|neutral)\.|^color\.white$')
                  .hasMatch(n),
        );
        expect(generated.length, roles.length);
        for (final role in roles) {
          final words = role.substring('color.'.length).split(RegExp('[.-]'));
          final id =
              words.first +
              words
                  .skip(1)
                  .map((w) => w[0].toUpperCase() + w.substring(1))
                  .join();
          final expected = parseColor(theme[role]!.value);
          final actual = _parseColorSource(generated[id]!);
          expect(actual.hex, expected.hex, reason: role);
          expect(actual.alpha, closeTo(expected.alpha, 1e-9), reason: role);
        }
      }
    });

    test(r'$description의 개행은 줄마다 ///로 나온다', () {
      final token = themes.lightKo['color.bg.base']!;
      final edited = TokenThemes(
        lightKo: {
          ...themes.lightKo,
          token.name: ResolvedToken(
            name: token.name,
            type: token.type,
            value: token.value,
            description: '첫째 줄\n둘째 줄',
            extensions: token.extensions,
          ),
        },
        darkKo: themes.darkKo,
        lightJa: themes.lightJa,
      );
      final out = generateTokensSource(edited);
      expect(out, matches(RegExp(r'^\s*/// 첫째 줄$', multiLine: true)));
      expect(out, matches(RegExp(r'^\s*/// 둘째 줄$', multiLine: true)));
    });

    test('커밋된 tokens.g.dart가 다시 생성한 결과와 정확히 같다', () async {
      final regenerated = await formatDartSource(source);
      expect(
        File('lib/design/tokens/gen/tokens.g.dart').readAsStringSync(),
        regenerated,
      );
    });
  });

  test('짝 파일의 토큰 이름이 다르면 TokenError', () {
    final dir = Directory.systemTemp.createTempSync('tokens_pair_');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final name in [
      'primitive.tokens.json',
      'color.light.tokens.json',
      'typography.tokens.json',
      'typography.ja.tokens.json',
    ]) {
      File('$_tokenDir/$name').copySync('${dir.path}/$name');
    }
    final dark = _readTokenFile('color.dark.tokens.json');
    // 다른 토큰이 참조하지 않는 리프를 지워, 깨진 참조가 아닌 짝 검사가 걸리게 한다.
    final colors = dark['color']! as Map<String, Object?>;
    (colors['skeleton']! as Map<String, Object?>).remove('bone');
    File('${dir.path}/color.dark.tokens.json')
        .writeAsStringSync(jsonEncode(dark));
    expect(
      () => loadThemes(dir.path),
      throwsA(
        isA<TokenError>()
            .having((e) => e.message, 'message', contains('짝 파일'))
            .having(
              (e) => e.message,
              'message',
              contains('color.skeleton.bone'),
            ),
      ),
    );
  });

  group('생성된 Dart 값', () {
    test('seal.fill은 action.primary와 같은 색이다', () {
      expect(lightColors.sealFill, lightColors.actionPrimary);
      expect(darkColors.sealFill, darkColors.actionPrimary);
    });

    test('알파가 있는 색: chip.bg 0.70 / 0.08, scrim 0.32 / 0.50', () {
      expect(lightColors.chipBg.a, closeTo(0.70, 0.005));
      expect(darkColors.chipBg.a, closeTo(0.08, 0.005));
      expect(lightColors.scrim.a, closeTo(0.32, 0.005));
      expect(darkColors.scrim.a, closeTo(0.50, 0.005));
    });

    test('불투명 색의 채널이 hex와 같다', () {
      expect(lightColors.ohaengWoodSwatch.toARGB32(), 0xFF418E47);
    });

    test('type.* 은 lineHeight를 height로, tnum을 tabularFigures로 바꾼다', () {
      expect(koType.sentenceCard.height, 1.65);
      expect(jaType.sentenceCard.height, 1.75);
      expect(koType.sentenceCard.fontSize, 17);
      expect(koType.display.letterSpacing, -0.48);
      expect(koType.display.fontWeight, FontWeight.w600);
      expect(koType.sentenceCard.fontFamily, 'Gowun Dodum');
      expect(koType.sentenceCard.fontFamilyFallback, [
        'Pretendard',
        'sans-serif',
      ]);
      expect(jaType.sentenceCard.fontFamily, 'Zen Maru Gothic');
      expect(koType.numericCalendar.fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
      expect(koType.display.fontFeatures, isNull);
    });

    test('간격·반경·움직임·그림자·그라데이션', () {
      expect(Space.s16, 16);
      expect(Space.s20, 20);
      expect(Radii.md, 12);
      expect(Motion.short, const Duration(milliseconds: 200));
      expect(Motion.toastHold, const Duration(milliseconds: 2500));
      expect(Motion.seep, const Cubic(0.2, 0.7, 0.2, 1));
      expect(Shadows.raised.single.blurRadius, 16);
      expect(Shadows.raised.single.offset, const Offset(0, 4));
      expect(Shadows.raised.single.color.a, closeTo(0.14, 0.005));
      final today = lightGradients.today;
      expect(today.colors, hasLength(2));
      expect(today.stops, [0, 1]);
      expect(today.begin, Alignment.centerLeft);
      expect(today.end, Alignment.centerRight);
      expect(today.transform, const CssAngleGradientTransform(160));
      expect(darkGradients.today.colors.first, isNot(today.colors.first));
    });
  });
}
