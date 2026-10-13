// 디자인 토큰 계약(../docs/identity/design/tokens/)을 Dart 상수로 생성합니다.
// 실행: dart run tool/gen_tokens.dart

import 'dart:convert';
import 'dart:io';

import 'common/dart_format.dart';
import 'tokens/dtcg.dart';

const _tokenDir = '../docs/identity/design/tokens';
const _outputPath = 'lib/design/tokens/gen/tokens.g.dart';

/// 생성 코드에 노출하지 않는 원시 팔레트. 위젯은 의미 역할만 씁니다.
const _rawPaletteGroups = ['color.sage.', 'color.coral.', 'color.neutral.'];
const _rawPaletteTokens = ['color.white'];

bool _isRawPalette(String name) =>
    _rawPaletteTokens.contains(name) || _rawPaletteGroups.any(name.startsWith);

/// 테마 4조합(색 모드 × 글자 언어)을 푼 결과. 영어는 한국어 글자 파일을 씁니다.
class TokenThemes {
  const new({
    required this.lightKo,
    required this.darkKo,
    required this.lightJa,
  });

  final Map<String, ResolvedToken> lightKo;
  final Map<String, ResolvedToken> darkKo;
  final Map<String, ResolvedToken> lightJa;
}

/// [dir]의 토큰 파일로 테마를 풀고, 짝 파일의 이름 집합이 같은지 확인합니다.
TokenThemes loadThemes(String dir) {
  Map<String, Object?> read(String name) =>
      jsonDecode(File('$dir/$name').readAsStringSync()) as Map<String, Object?>;

  Map<String, ResolvedToken> theme(String mode, String typography) =>
      resolveTheme([
        read('primitive.tokens.json'),
        read('color.$mode.tokens.json'),
        read(typography),
      ]);

  final themes = TokenThemes(
    lightKo: theme('light', 'typography.tokens.json'),
    darkKo: theme('dark', 'typography.tokens.json'),
    lightJa: theme('light', 'typography.ja.tokens.json'),
  );
  _checkSameNames('라이트·다크', themes.lightKo, themes.darkKo);
  _checkSameNames('한국어·일본어', themes.lightKo, themes.lightJa);
  return themes;
}

void _checkSameNames(
  String pair,
  Map<String, ResolvedToken> a,
  Map<String, ResolvedToken> b,
) {
  final onlyA = a.keys.toSet().difference(b.keys.toSet());
  final onlyB = b.keys.toSet().difference(a.keys.toSet());
  if (onlyA.isNotEmpty || onlyB.isNotEmpty) {
    throw TokenError('$pair 짝 파일의 토큰 이름이 다릅니다: $onlyA / $onlyB');
  }
}

/// 테마에서 생성 소스를 만듭니다.
String generateTokensSource(TokenThemes themes) {
  final out = StringBuffer()
    ..writeln('// 생성 코드: dart run tool/gen_tokens.dart. 손으로 고치지 않습니다.')
    ..writeln()
    ..writeln("import 'dart:ui';")
    ..writeln()
    ..writeln("import 'package:flutter/animation.dart';")
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln("import 'package:myungli_diary/design/tokens/css_gradient.dart';")
    ..writeln();

  _writeColors(out, themes);
  _writeTypes(out, themes);
  _writeGradients(out, themes);
  _writeSpace(out, themes.lightKo);
  _writeRadii(out, themes.lightKo);
  _writeMotion(out, themes.lightKo);
  _writeShadows(out, themes.lightKo);
  return out.toString();
}

// ---- 이름 ----

/// `bg.base` → `bgBase`, `toast-hold` → `toastHold`.
String _camel(String path) {
  final words = path.split(RegExp('[.-]'));
  return words.first +
      words
          .skip(1)
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join();
}

/// [names]의 Dart 식별자가 겹치지 않는지 확인하고 (토큰 이름 → 식별자) 순서대로 돌려줍니다.
Map<String, String> _identifiers(
  Iterable<String> names,
  String Function(String) toId,
) {
  final byId = <String, String>{};
  final result = <String, String>{};
  for (final name in names) {
    final id = toId(name);
    final previous = byId[id];
    if (previous != null) {
      throw TokenError("'$previous'와 '$name'이 같은 이름 '$id'가 됩니다.");
    }
    byId[id] = name;
    result[name] = id;
  }
  return result;
}

Iterable<String> _namesUnder(Map<String, ResolvedToken> theme, String prefix) =>
    theme.keys.where((name) => name.startsWith(prefix));

String _docComment(ResolvedToken token) {
  final description = token.description;
  if (description == null) {
    return '';
  }
  return description.split('\n').map((line) => '/// $line\n').join();
}

// ---- 값 ----

String _number(num value) {
  final text = value.toDouble().toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String _hex2(int channel) => channel.toRadixString(16).padLeft(2, '0');

String _colorSource(Object? value) {
  final color = parseColor(value);
  if (color.alpha == 1) {
    return 'Color(0xFF${color.hex.substring(1).toUpperCase()})';
  }
  // 알파가 있으면 채널을 255로 나눈 값으로 정확히 보존한다.
  return 'Color.from('
      'alpha: ${_number(color.alpha)}, '
      'red: 0x${_hex2(color.red)} / 255, '
      'green: 0x${_hex2(color.green)} / 255, '
      'blue: 0x${_hex2(color.blue)} / 255)';
}

// ---- 색 ----

bool _isColorRole(String name) =>
    name.startsWith('color.') && !_isRawPalette(name);

void _writeColors(StringBuffer out, TokenThemes themes) {
  final names = themes.lightKo.keys.where(_isColorRole).toList();
  final ids = _identifiers(names, (n) => _camel(n.substring('color.'.length)));

  out
    ..writeln('/// 의미 역할 색. 라이트·다크가 같은 이름을 씁니다.')
    ..writeln('final class ColorTokens {')
    ..writeln('const ColorTokens({');
  for (final name in names) {
    out.writeln('required this.${ids[name]},');
  }
  out.writeln('});');
  for (final name in names) {
    out
      ..write(_docComment(themes.lightKo[name]!))
      ..writeln('final Color ${ids[name]};');
  }
  out
    ..writeln('}')
    ..writeln();
  for (final (constName, theme) in [
    ('lightColors', themes.lightKo),
    ('darkColors', themes.darkKo),
  ]) {
    out.writeln('const $constName = ColorTokens(');
    for (final name in names) {
      out.writeln('${ids[name]}: ${_colorSource(theme[name]!.value)},');
    }
    out
      ..writeln(');')
      ..writeln();
  }
}

// ---- 글자 ----

void _writeTypes(StringBuffer out, TokenThemes themes) {
  final names = _namesUnder(themes.lightKo, 'type.').toList();
  final ids = _identifiers(names, (n) => _camel(n.substring('type.'.length)));

  out
    ..writeln('/// 글자 스타일. 언어마다 글꼴과 행간·자간이 다릅니다.')
    ..writeln('final class TypeTokens {')
    ..writeln('const TypeTokens({');
  for (final name in names) {
    out.writeln('required this.${ids[name]},');
  }
  out.writeln('});');
  for (final name in names) {
    out
      ..write(_docComment(themes.lightKo[name]!))
      ..writeln('final TextStyle ${ids[name]};');
  }
  out
    ..writeln('}')
    ..writeln();
  for (final (constName, theme) in [
    ('koType', themes.lightKo),
    ('jaType', themes.lightJa),
  ]) {
    out.writeln('const $constName = TypeTokens(');
    for (final name in names) {
      out.writeln('${ids[name]}: ${_textStyleSource(theme[name]!)},');
    }
    out
      ..writeln(');')
      ..writeln();
  }
}

String _textStyleSource(ResolvedToken token) {
  final value = token.value! as Map<String, Object?>;
  final families = (value['fontFamily']! as List<Object?>).cast<String>();
  final weight = (value['fontWeight']! as num).toInt();
  if (weight < 100 || weight > 900 || weight % 100 != 0) {
    throw TokenError("'${token.name}'의 fontWeight $weight는 FontWeight에 없습니다.");
  }
  final fontFeatures = (token.extensions['fontFeatures'] as List<Object?>?)
      ?.cast<String>();
  final features = fontFeatures == null
      ? ''
      : ', fontFeatures: [${fontFeatures.map(_fontFeatureSource).join(', ')}]';

  return 'TextStyle('
      'fontFamily: ${_quote(families.first)}, '
      'fontFamilyFallback: [${families.skip(1).map(_quote).join(', ')}], '
      'fontSize: ${_number(parseDimension(value['fontSize']))}, '
      'fontWeight: FontWeight.w$weight, '
      'letterSpacing: ${_number(parseDimension(value['letterSpacing']))}, '
      'height: ${_number(value['lineHeight']! as num)}'
      '$features)';
}

String _fontFeatureSource(String feature) => switch (feature) {
  'tnum' => 'FontFeature.tabularFigures()',
  _ => throw TokenError("알 수 없는 fontFeature '$feature'입니다."),
};

/// Dart 작은따옴표 문자열 리터럴로 만듭니다.
String _quote(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

// ---- 그라데이션 ----

void _writeGradients(StringBuffer out, TokenThemes themes) {
  final names = themes.lightKo.values
      .where((token) => token.type == 'gradient')
      .map((token) => token.name)
      .toList();
  final ids = _identifiers(
    names,
    (n) => _camel(n.substring('gradient.'.length)),
  );

  out
    ..writeln('/// 그라데이션. 각도는 CSS 기준(0°=위쪽, 시계 방향)이며 박스 크기에 맞춰 변환됩니다.')
    ..writeln('final class GradientTokens {')
    ..writeln('const GradientTokens({');
  for (final name in names) {
    out.writeln('required this.${ids[name]},');
  }
  out.writeln('});');
  for (final name in names) {
    out
      ..write(_docComment(themes.lightKo[name]!))
      ..writeln('final LinearGradient ${ids[name]};');
  }
  out
    ..writeln('}')
    ..writeln();
  for (final (constName, theme) in [
    ('lightGradients', themes.lightKo),
    ('darkGradients', themes.darkKo),
  ]) {
    out.writeln('const $constName = GradientTokens(');
    for (final name in names) {
      out.writeln('${ids[name]}: ${_gradientSource(theme[name]!)},');
    }
    out
      ..writeln(');')
      ..writeln();
  }
}

String _gradientSource(ResolvedToken token) {
  final angle = token.extensions['angle'];
  if (angle is! num) {
    throw TokenError("'${token.name}'에 angle 확장이 없습니다.");
  }
  final stops = (token.value! as List<Object?>).cast<Map<String, Object?>>();
  final colors = stops.map((stop) => _colorSource(stop['color'])).join(', ');
  final positions = stops
      .map((stop) => _number(stop['position']! as num))
      .join(', ');
  // 박스 크기에 맞는 CSS 각도 변환은 손으로 쓴 css_gradient.dart가 합니다.
  return 'LinearGradient('
      'begin: Alignment.centerLeft, end: Alignment.centerRight, '
      'colors: [$colors], stops: [$positions], '
      'transform: CssAngleGradientTransform(${_number(angle)}))';
}

// ---- 간격·반경 ----

void _writeSpace(StringBuffer out, Map<String, ResolvedToken> theme) {
  final names = _namesUnder(theme, 'space.').toList();
  final ids = _identifiers(names, (n) => 's${n.substring('space.'.length)}');
  out.writeln('/// 간격(logical px).\nabstract final class Space {');
  for (final name in names) {
    out.writeln(
      'static const double ${ids[name]} = '
      '${_number(parseDimension(theme[name]!.value))};',
    );
  }
  out
    ..writeln('}')
    ..writeln();
}

void _writeRadii(StringBuffer out, Map<String, ResolvedToken> theme) {
  final names = _namesUnder(theme, 'radius.').toList();
  final ids = _identifiers(names, (n) => _camel(n.substring('radius.'.length)));
  out.writeln('/// 모서리 반경(logical px).\nabstract final class Radii {');
  for (final name in names) {
    out.writeln(
      'static const double ${ids[name]} = '
      '${_number(parseDimension(theme[name]!.value))};',
    );
  }
  out
    ..writeln('}')
    ..writeln();
}

// ---- 움직임 ----

void _writeMotion(StringBuffer out, Map<String, ResolvedToken> theme) {
  final names = [
    ..._namesUnder(theme, 'motion.duration.'),
    ..._namesUnder(theme, 'motion.easing.'),
  ];
  final ids = _identifiers(
    names,
    (n) => _camel(n.split('.').skip(2).join('.')),
  );
  out.writeln('/// 움직임 시간과 곡선.\nabstract final class Motion {');
  for (final name in names) {
    final token = theme[name]!;
    if (token.type == 'duration') {
      out.writeln(
        'static const Duration ${ids[name]} = '
        'Duration(milliseconds: ${parseDurationMs(token.value)});',
      );
    } else {
      final points = (token.value! as List<Object?>).cast<num>();
      if (points.length != 4) {
        throw TokenError("'$name'의 cubicBezier는 숫자 4개여야 합니다.");
      }
      out.writeln(
        'static const Cubic ${ids[name]} = '
        'Cubic(${points.map(_number).join(', ')});',
      );
    }
  }
  out
    ..writeln('}')
    ..writeln();
}

// ---- 그림자 ----

String _boxShadowSource(Map<String, Object?> layer) {
  final offsetX = _number(parseDimension(layer['offsetX']));
  final offsetY = _number(parseDimension(layer['offsetY']));
  final blur = _number(parseDimension(layer['blur']));
  final spread = _number(parseDimension(layer['spread']));
  return 'BoxShadow(color: ${_colorSource(layer['color'])}, '
      'offset: Offset($offsetX, $offsetY), '
      'blurRadius: $blur, spreadRadius: $spread)';
}

void _writeShadows(StringBuffer out, Map<String, ResolvedToken> theme) {
  final names = _namesUnder(theme, 'shadow.').toList();
  final ids = _identifiers(names, (n) => _camel(n.substring('shadow.'.length)));
  out.writeln('/// 그림자.\nabstract final class Shadows {');
  for (final name in names) {
    final raw = theme[name]!.value;
    final layers = raw is List<Object?> ? raw : [raw];
    final sources = [
      for (final layer in layers.cast<Map<String, Object?>>())
        _boxShadowSource(layer),
    ];
    out.writeln(
      'static const List<BoxShadow> ${ids[name]} = [${sources.join(', ')}];',
    );
  }
  out.writeln('}');
}

Future<void> main() async {
  final source = await formatDartSource(
    generateTokensSource(loadThemes(_tokenDir)),
  );
  final output = File(_outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(source);
}
