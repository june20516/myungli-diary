@Tags(['contract'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/common/open_enums.dart';
import '../../tool/common/openapi_spec.dart';

/// 생성 모델 디렉터리(app/ 기준).
const _modelDir = 'lib/core/api/gen/model';

/// 생성기가 모르는 값에 쓰는 enum 값 이름.
const _unknownValue = 'unknownDefaultOpenApi';

String _snake(String name) => name
    .replaceAllMapped(RegExp('(?<=[a-z0-9])([A-Z])'), (m) => '_${m[1]}')
    .toLowerCase();

/// 생성 모델 파일 이름 → 내용.
Map<String, String> _modelSources() => {
  for (final file in Directory(_modelDir).listSync().whereType<File>())
    if (file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
      file.uri.pathSegments.last: file.readAsStringSync(),
};

/// 생성 코드의 enum 이름 → 본문.
Map<String, String> _enums(Map<String, String> sources) => {
  for (final source in sources.values)
    for (final match in RegExp(
      r'^enum (\w+) \{(.*?)^\}',
      multiLine: true,
      dotAll: true,
    ).allMatches(source))
      match[1]!: match[2]!,
};

/// `@JsonKey(...)` 바로 뒤 필드 선언. (JsonKey 인자, 필드 타입)
final _field = RegExp(
  r'@JsonKey\((.*?)\)\s*final ([\w<>?]+) \w+;',
  dotAll: true,
);

String _elementType(String type) => type
    .replaceAll('?', '')
    .replaceFirstMapped(RegExp(r'^List<(\w+)>$'), (m) => m[1]!);

/// 계약 열린 enum 이름이 생성 코드에서 어떤 Dart enum인지 찾습니다.
String _dartEnumOf(String contractName, Map<String, String> sources) {
  final parts = contractName.split('.');
  if (parts.length == 1) {
    return parts.single;
  }
  final source = sources['${_snake(parts.first)}.dart'];
  if (source == null) {
    fail('$contractName: 생성 모델 ${_snake(parts.first)}.dart가 없습니다');
  }
  for (final match in _field.allMatches(source)) {
    if (match[1]!.contains("name: r'${parts.last}'")) {
      return _elementType(match[2]!);
    }
  }
  fail('$contractName: 생성 모델에 ${parts.last} 필드가 없습니다');
}

void main() {
  final sources = _modelSources();
  final enums = _enums(sources);
  final targets = resolveOpenEnums(loadOpenApi());

  test('계약에서 열린 enum을 읽고 생성 모델을 찾는다', () {
    // 계약 목록이 바뀌면 이 집합이 무엇이 늘거나 줄었는지 보여 줍니다.
    expect(targets.where((t) => t.isEnum).map((t) => t.name).toSet(), {
      'NoticeCode',
      'ShinsalKind',
      'RelationKind',
      'PersonalReading.kind',
      'FocusSlot.reasons',
      'SlotText.variant',
      'Insight.source',
      'ConsentDocument.document',
      'LoginProvider',
    });
    expect(targets.where((t) => !t.isEnum).map((t) => t.name), [
      'Problem.code',
    ]);
    expect(enums, contains('NoticeCode'));
  });

  test('모르는 값을 견디는 enum = 계약의 열린 enum (닫힌 enum은 견디지 않음)', () {
    final expected = {
      for (final target in targets.where((t) => t.isEnum))
        _dartEnumOf(target.name, sources),
    };
    final tolerant = {
      for (final MapEntry(:key, :value) in enums.entries)
        if (value.contains('$_unknownValue(')) key,
    };
    expect(tolerant, expected);
    expect(
      expected.difference(enums.keys.toSet()),
      isEmpty,
      reason: '생성 코드에 없는 enum',
    );
  });

  test('열린 enum은 isKnown을 갖는다', () {
    for (final MapEntry(:key, :value) in enums.entries) {
      if (value.contains('$_unknownValue(')) {
        expect(
          value,
          contains('bool get isKnown => this != $_unknownValue;'),
          reason: key,
        );
      }
    }
  });

  test('열린 enum을 쓰는 모든 필드(목록 항목 포함)가 모르는 값을 그 값으로 읽는다', () {
    final tolerant = {
      for (final MapEntry(:key, :value) in enums.entries)
        if (value.contains('$_unknownValue(')) key,
    };
    // 열린 enum을 쓰는 필드 `모델 파일:JSON 이름`.
    final fields = <String>{};
    for (final MapEntry(key: file, value: source) in sources.entries) {
      for (final match in _field.allMatches(source)) {
        final type = _elementType(match[2]!);
        if (!tolerant.contains(type)) continue;
        final name = RegExp(r"name: r'(\w+)'").firstMatch(match[1]!)![1];
        fields.add('$file:$name');
        expect(
          match[1],
          contains('unknownEnumValue: $type.$_unknownValue'),
          reason: '$file의 $name',
        );
      }
    }
    // 쓰는 곳이 바뀌면 이 집합이 무엇이 늘거나 줄었는지 보여 줍니다.
    expect(fields, {
      'notice.dart:code',
      'shinsal_at.dart:kind',
      'relation.dart:kind',
      'relation.dart:suppressedBy',
      'seun_year.dart:relationsWithNatal',
      'personal_reading.dart:kind',
      'personal_reading.dart:shinsal',
      'focus_slot.dart:reasons',
      'slot_text.dart:variant',
      'insight.dart:source',
      'consent_document.dart:document',
      'identity.dart:provider',
      'merge_account_summary.dart:providers',
    });
  });
}
