import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// `flutter.fonts`를 (family, asset, weight) 문자열 집합으로 펼칩니다.
/// Widgetbook의 `../assets/` 접두사는 app의 `assets/`와 같게 맞춥니다.
Set<String> _fonts(String pubspecPath) {
  final yaml = loadYaml(File(pubspecPath).readAsStringSync()) as YamlMap;
  final fonts = (yaml['flutter']! as YamlMap)['fonts']! as YamlList;
  return {
    for (final family in fonts.cast<YamlMap>())
      for (final font in (family['fonts']! as YamlList).cast<YamlMap>())
        [
          family['family'],
          (font['asset']! as String).replaceFirst('../', ''),
          font['weight'] ?? '',
        ].join('|'),
  };
}

void main() {
  test('app과 Widgetbook의 flutter.fonts 선언이 같습니다', () {
    final app = _fonts('pubspec.yaml');
    expect(app, isNotEmpty);
    expect(_fonts('widgetbook/pubspec.yaml'), app);
  });
}
