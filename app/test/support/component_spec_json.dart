import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/component_spec.dart';

/// 컴포넌트 명세 디렉터리(app/ 기준 상대 경로).
const String componentsDir = '../docs/identity/design/components';

/// 명세 묶음 파일(상호작용·요소 제외)에서 컴포넌트 JSON을 id별로 읽습니다.
Map<String, Map<String, Object?>> loadSpecComponents() {
  final result = <String, Map<String, Object?>>{};
  final files =
      Directory(componentsDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .where(
            (f) =>
                !f.path.endsWith('interaction.json') &&
                !f.path.endsWith('elements.json'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    for (final component in json['components']! as List<Object?>) {
      final map = component! as Map<String, Object?>;
      result[map['id']! as String] = map;
    }
  }
  return result;
}

/// 명세 JSON의 `variants[].id` 집합. `variants`는 list 또는 없음(null)이어야 합니다.
Set<String> variantIds(Map<String, Object?> component) {
  final variants = component['variants'];
  expect(
    variants,
    anyOf(isNull, isA<List<Object?>>()),
    reason: '${component['id']}: variants는 list 또는 null',
  );
  return {
    for (final variant in (variants as List<Object?>?) ?? <Object?>[])
      _variantId(component, variant),
  };
}

String _variantId(Map<String, Object?> component, Object? variant) {
  expect(variant, isA<Map<String, Object?>>(), reason: '${component['id']}');
  final id = (variant! as Map<String, Object?>)['id'];
  expect(id, isA<String>(), reason: '${component['id']}: variant id는 문자열');
  return id! as String;
}

/// 명세 JSON의 `states` 키 집합. `states`는 dict 또는 없음(null)이어야 합니다.
Set<String> stateKeys(Map<String, Object?> component) {
  final states = component['states'];
  expect(
    states,
    anyOf(isNull, isA<Map<String, Object?>>()),
    reason: '${component['id']}: states는 dict 또는 null',
  );
  return {...((states as Map<String, Object?>?) ?? <String, Object?>{}).keys};
}

/// [spec]의 변형·상태가 명세 JSON [component]와 같은지 확인합니다.
void expectSpecMatches(ComponentSpec spec, Map<String, Object?> component) {
  expect(spec.id, component['id'], reason: 'id');
  expect(spec.variants, variantIds(component), reason: '${spec.id} variants');
  expect(spec.states, stateKeys(component), reason: '${spec.id} states');
}
