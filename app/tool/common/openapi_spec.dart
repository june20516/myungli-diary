// OpenAPI 계약을 읽는 공용 도우미입니다. 순수 Dart만 import합니다.

import 'dart:io';

import 'package:yaml/yaml.dart';

/// 계약 파일 경로(app/ 기준).
const openApiPath = '../server/api/openapi.yaml';

/// YAML 노드를 일반 Map·List·스칼라로 바꿉니다.
Object? plainYaml(Object? node) {
  if (node is YamlMap) {
    return {for (final e in node.entries) e.key as String: plainYaml(e.value)};
  }
  if (node is YamlList) {
    return [for (final e in node) plainYaml(e)];
  }
  return node;
}

/// 계약을 읽어 일반 Map으로 돌려줍니다.
Map<String, Object?> loadOpenApi([String path = openApiPath]) {
  final text = File(path).readAsStringSync();
  return plainYaml(loadYaml(text))! as Map<String, Object?>;
}
