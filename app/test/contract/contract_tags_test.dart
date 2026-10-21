import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 저장소의 계약 파일(`../docs/`·`../server/`)을 가리키는 경로 문자열.
final RegExp _contractPath = RegExp(r'''['"]\.\./(docs|server)/''');

/// 상대 경로 import(`import '../support/x.dart';`).
final RegExp _relativeImport = RegExp(
  r'''^import\s+'([^':]+\.dart)'\s*;''',
  multiLine: true,
);

/// 파일 머리의 `@Tags([... 'contract' ...])`.
final RegExp _contractTag = RegExp(
  r'''^@Tags\(\[[^\]]*'contract'[^\]]*\]\)''',
  multiLine: true,
);

/// [test]가 계약 파일을 읽는지: 직접 경로를 쓰거나, 그런 파일을 상대 경로로 import합니다.
bool _readsContract(File test) {
  final source = test.readAsStringSync();
  if (_contractPath.hasMatch(source)) {
    return true;
  }
  return _relativeImport.allMatches(source).any((match) {
    final imported = File.fromUri(test.uri.resolve(match[1]!));
    return imported.existsSync() &&
        _contractPath.hasMatch(imported.readAsStringSync());
  });
}

void main() {
  // ci-gate의 drift·gate 호출은 `flutter test --tags contract`만 돌립니다(D81). 계약을 읽는
  // 테스트가 태그를 빠뜨리면 계약 변경이 깨뜨린 것을 drift에서 놓치고, 읽지 않는 테스트에
  // 태그가 붙으면 다른 단위 PR의 검사가 길어집니다.
  test('계약 파일을 읽는 테스트에만 contract 태그가 있습니다', () {
    final missing = <String>[];
    final extra = <String>[];
    final tests = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('_test.dart'));
    for (final file in tests) {
      final tagged = _contractTag.hasMatch(file.readAsStringSync());
      final reads = _readsContract(file);
      if (reads && !tagged) {
        missing.add(file.path);
      } else if (tagged && !reads) {
        extra.add(file.path);
      }
    }
    expect(missing..sort(), isEmpty, reason: "@Tags(['contract'])가 필요합니다");
    expect(extra..sort(), isEmpty, reason: '계약 파일을 읽지 않아 태그를 뺍니다');
  });
}
