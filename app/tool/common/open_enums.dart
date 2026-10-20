// 계약의 열린 enum(info.description "호환과 버전" 절)을 읽고, 생성용 계약 사본에 표시를 답니다.
// 순수 Dart만 import합니다. 결정 A66.

import 'dart:convert';

/// 생성용 계약 사본에서 열린 enum 노드에 다는 vendor extension 이름.
/// 생성 템플릿 patch(`tool/openapi-templates/open_enum.patch`)가 이 이름을 봅니다.
const openEnumExtension = 'x-myungli-open-enum';

/// 열린 enum 목록이 시작하는 말과 끝나는 말(계약 `info.description`).
const _listStart = '열린 enum:';
const _listEnd = '그 밖의 enum';

/// 계약이 열린 enum으로 정한 이름을 적힌 순서대로 돌려줍니다.
///
/// 이름은 스키마(`NoticeCode`)나 스키마의 속성(`PersonalReading.kind`)입니다. 배열 속성
/// (`FocusSlot.reasons`)은 그 항목을 뜻합니다. 절이나 이름이 없으면 [FormatException]입니다.
List<String> contractOpenEnumNames(Map<String, Object?> spec) {
  final info = spec['info'];
  final description = info is Map<String, Object?> ? info['description'] : null;
  if (description is! String) {
    throw const FormatException('계약에 info.description이 없습니다');
  }
  final from = description.indexOf(_listStart);
  final to = from < 0 ? -1 : description.indexOf(_listEnd, from);
  if (from < 0 || to < 0) {
    throw const FormatException(
      '계약 info.description에서 "$_listStart" … "$_listEnd" 절을 찾지 못했습니다',
    );
  }
  final names = [
    for (final match in RegExp(
      '`([^`]+)`',
    ).allMatches(description.substring(from, to)))
      match.group(1)!,
  ];
  if (names.isEmpty) {
    throw const FormatException('열린 enum 절에 이름이 없습니다');
  }
  return names;
}

/// 열린 enum 이름 하나가 가리키는 계약 노드.
final class OpenEnumTarget {
  /// [name]과 그 노드 [node](열린 문자열이면 null).
  const new(this.name, this.node);

  /// 계약에 적힌 이름(예 `FocusSlot.reasons`).
  final String name;

  /// `enum`이 있는 노드(배열이면 그 항목). 열린 문자열이면 null입니다.
  final Map<String, Object?>? node;

  /// 생성 코드에 enum이 생기는지. 아니면 열린 문자열(`Problem.code`처럼 enum 없는
  /// string, 값 목록은 설명·`x-problem-codes`에 있음)입니다.
  bool get isEnum => node != null;
}

/// 계약의 열린 enum 이름을 모두 노드로 찾습니다. 찾지 못하면 [FormatException]입니다.
List<OpenEnumTarget> resolveOpenEnums(Map<String, Object?> spec) => [
  for (final name in contractOpenEnumNames(spec)) _resolve(spec, name),
];

OpenEnumTarget _resolve(Map<String, Object?> spec, String name) {
  final parts = name.split('.');
  if (parts.length > 2) {
    throw FormatException('열린 enum "$name": 스키마나 스키마.속성만 쓸 수 있습니다');
  }
  final components = spec['components'];
  final schemas = components is Map<String, Object?>
      ? components['schemas']
      : null;
  var node = schemas is Map<String, Object?> ? schemas[parts.first] : null;
  if (parts.length == 2) {
    final properties = node is Map<String, Object?> ? node['properties'] : null;
    node = properties is Map<String, Object?> ? properties[parts.last] : null;
  }
  if (node is! Map<String, Object?>) {
    throw FormatException('열린 enum "$name": 계약에 그 스키마나 속성이 없습니다');
  }
  if (node['type'] == 'array') {
    final items = node['items'];
    if (items is! Map<String, Object?>) {
      throw FormatException('열린 enum "$name": 배열 항목이 없습니다');
    }
    node = items;
  }
  if (node.containsKey(r'$ref')) {
    // 참조된 enum은 쓰는 곳이 여럿일 수 있어 스키마 이름으로 적힌 경우만 받습니다.
    throw FormatException('열린 enum "$name": \$ref 속성입니다. 참조된 스키마 이름으로 적어야 합니다');
  }
  if (node['enum'] is List<Object?>) {
    return OpenEnumTarget(name, node);
  }
  if (node['type'] == 'string') {
    return OpenEnumTarget(name, null);
  }
  throw FormatException('열린 enum "$name": enum도 string도 아닙니다');
}

/// [spec]의 사본에서 열린 enum 노드마다 [openEnumExtension]을 true로 단 계약을 돌려줍니다.
/// [spec]은 바꾸지 않습니다.
Map<String, Object?> markOpenEnums(Map<String, Object?> spec) {
  final copy = jsonDecode(jsonEncode(spec)) as Map<String, Object?>;
  for (final target in resolveOpenEnums(copy)) {
    target.node?[openEnumExtension] = true;
  }
  return copy;
}
