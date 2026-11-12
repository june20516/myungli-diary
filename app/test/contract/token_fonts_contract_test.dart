@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/type_styles.dart';

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

/// typography 토큰 파일의 `$type: fontFamily` 값(이름 목록) 전부.
List<List<String>> _contractFamilyLists() {
  final lists = <List<String>>[];
  void visit(Object? node) {
    if (node is! Map<String, Object?>) return;
    if (node[r'$type'] == 'fontFamily' && node[r'$value'] is List) {
      lists.add((node[r'$value']! as List).cast<String>());
    }
    node.values.forEach(visit);
  }

  final files = Directory(_tokenDir).listSync().whereType<File>().where(
    (f) => RegExp(r'typography(\.\w+)?\.tokens\.json$').hasMatch(f.path),
  );
  for (final file in files) {
    visit(jsonDecode(file.readAsStringSync()));
  }
  return lists;
}

void main() {
  final declared = _pubspecFamilies();
  final contractLists = _contractFamilyLists();

  test('계약 typography 토큰의 글꼴 이름(일반 이름 제외)이 모두 pubspec family에 있습니다', () {
    final contract = {for (final list in contractLists) ...list}
        .difference(_genericFamilies);
    expect(contract, isNotEmpty);
    expect(contract.difference(declared), isEmpty);
  });

  test(
    '생성 토큰의 fontFamilyFallback 이름은 계약의 대체 글꼴 이름이고 모두 pubspec family에 있습니다',
    () {
      // 계약 목록의 첫 값은 fontFamily, 나머지가 대체 목록입니다(gen_tokens.dart).
      final contractFallbacks = {
        for (final list in contractLists) ...list.skip(1),
      }.difference(_genericFamilies);
      final generated = {
        for (final style in allTypeStyles()) ...?style.fontFamilyFallback,
      }.difference(_genericFamilies);
      expect(generated, contractFallbacks);
      expect(generated.difference(declared), isEmpty);
    },
  );
}
