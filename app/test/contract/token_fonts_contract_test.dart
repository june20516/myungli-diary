@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:yaml/yaml.dart';

/// 디자인 토큰 계약 디렉터리(app/ 기준).
const _tokenDir = '../docs/identity/design/tokens';

/// 플랫폼이 고르는 일반 글꼴 이름. 앱에 싣지 않습니다.
const _genericFamilies = {'sans-serif'};

/// `pubspec.yaml`의 `flutter.fonts` family 이름.
Set<String> _pubspecFamilies() {
  final yaml = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final fonts = (yaml['flutter']! as YamlMap)['fonts']! as YamlList;
  return {
    for (final family in fonts.cast<YamlMap>()) family['family']! as String,
  };
}

/// typography 토큰 파일에서 `$type: fontFamily`인 값의 이름을 모두 모읍니다.
Set<String> _contractFamilies() {
  final names = <String>{};
  void visit(Object? node) {
    if (node is! Map<String, Object?>) return;
    if (node[r'$type'] == 'fontFamily' && node[r'$value'] is List) {
      names.addAll((node[r'$value']! as List).cast<String>());
    }
    node.values.forEach(visit);
  }

  final files = Directory(_tokenDir).listSync().whereType<File>().where(
    (f) => RegExp(r'typography(\.\w+)?\.tokens\.json$').hasMatch(f.path),
  );
  for (final file in files) {
    visit(jsonDecode(file.readAsStringSync()));
  }
  return names;
}

/// 생성 토큰의 모든 글자 스타일.
List<TextStyle> _generatedStyles() => [
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

void main() {
  final declared = _pubspecFamilies();

  test('계약 typography 토큰의 글꼴 이름(일반 이름 제외)이 모두 pubspec family에 있습니다', () {
    final contract = _contractFamilies().difference(_genericFamilies);
    // 한자 대체 글꼴(V121, 토큰 1.9.0)이 계약에 있는지도 함께 봅니다.
    expect(contract, contains('Myungli Hanja Supplement'));
    expect(contract.difference(declared), isEmpty);
  });

  test('생성 토큰의 fontFamilyFallback 이름(일반 이름 제외)이 모두 pubspec family에 있습니다', () {
    final fallbacks = {
      for (final style in _generatedStyles()) ...?style.fontFamilyFallback,
    }.difference(_genericFamilies);
    expect(fallbacks, contains('Myungli Hanja Supplement'));
    expect(fallbacks.difference(declared), isEmpty);
  });
}
