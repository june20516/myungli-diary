import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _import = RegExp(
  r'''^import\s+['"]package:myungli_diary/features/([a-z_]+)/([a-z_]+)/''',
  multiLine: true,
);

/// `lib/features/<영역>/<층>/` 파일이 다른 영역의 [forbiddenLayer] 층을 import한 줄.
///
/// [fromLayer]가 있으면 그 층의 파일만 봅니다.
List<String> _crossFeatureImports({
  required String forbiddenLayer,
  String? fromLayer,
}) {
  final violations = <String>[];
  final features = Directory('lib/features');
  for (final file in features.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) {
      continue;
    }
    final segments = file.uri.pathSegments;
    final featureIndex = segments.indexOf('features');
    final owner = segments[featureIndex + 1];
    if (fromLayer != null && segments[featureIndex + 2] != fromLayer) {
      continue;
    }
    for (final match in _import.allMatches(file.readAsStringSync())) {
      final target = match[1]!;
      final layer = match[2]!;
      if (target != owner && layer == forbiddenLayer) {
        violations.add('${file.path} -> features/$target/$forbiddenLayer');
      }
    }
  }
  return violations..sort();
}

void main() {
  test('features/<a>/presentation은 다른 feature의 presentation을 import하지 않습니다(spec §2)', () {
    // feature끼리는 서로의 application provider로만 참조합니다.
    expect(
      _crossFeatureImports(
        forbiddenLayer: 'presentation',
        fromLayer: 'presentation',
      ),
      isEmpty,
    );
  });

  test('features/<a>는 어느 층에서도 다른 feature의 data를 import하지 않습니다(spec §2)', () {
    // 저장소·저장 형식은 그 feature 안에 둡니다. 다른 feature가 쓰는 값 타입은 model/에,
    // 동작은 application provider에 둡니다. 허용 목록은 두지 않습니다.
    expect(_crossFeatureImports(forbiddenLayer: 'data'), isEmpty);
  });

  test('검사기가 위반을 실제로 찾습니다', () {
    final sample = RegExp(_import.pattern, multiLine: true).allMatches(
      "import 'package:myungli_diary/features/depth/presentation/x.dart';\n"
      "import 'package:myungli_diary/features/glossary/data/y.dart';",
    );
    expect(sample.map((m) => (m[1], m[2])), [
      ('depth', 'presentation'),
      ('glossary', 'data'),
    ]);
  });
}
