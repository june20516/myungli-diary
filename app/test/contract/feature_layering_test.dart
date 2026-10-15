import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _import = RegExp(
  r'''^import\s+['"]package:myungli_diary/features/([a-z_]+)/([a-z_]+)/''',
  multiLine: true,
);

/// `lib/features/<영역>/presentation` 파일이 다른 영역의 presentation을 import한 줄.
List<String> _crossPresentationImports() {
  final violations = <String>[];
  final features = Directory('lib/features');
  for (final file in features.listSync(recursive: true).whereType<File>()) {
    final segments = file.uri.pathSegments;
    final featureIndex = segments.indexOf('features');
    final owner = segments[featureIndex + 1];
    if (segments[featureIndex + 2] != 'presentation' ||
        !file.path.endsWith('.dart')) {
      continue;
    }
    for (final match in _import.allMatches(file.readAsStringSync())) {
      final target = match[1]!;
      final layer = match[2]!;
      if (target != owner && layer == 'presentation') {
        violations.add('${file.path} -> features/$target/presentation');
      }
    }
  }
  return violations..sort();
}

/// 이 규칙 이전부터 있던 위반(공용 레이아웃 위젯 `onboarding_page_layout`). 새로 늘리지 않고,
/// 위젯이 `design/`이나 공용 자리로 옮겨 가면 이 목록에서 지웁니다.
const Set<String> _knownViolations = {
  'lib/features/auth/presentation/consent_screen.dart -> features/onboarding/presentation',
  'lib/features/auth/presentation/login_screen.dart -> features/onboarding/presentation',
};

void main() {
  test('features/<a>/presentation은 다른 feature의 presentation을 import하지 않습니다(spec §2)', () {
    // feature끼리는 서로의 application provider로만 참조합니다.
    expect(
      _crossPresentationImports().where(
        (line) => !_knownViolations.contains(line),
      ),
      isEmpty,
    );
  });

  test('검사기가 위반을 실제로 찾습니다', () {
    final sample = RegExp(_import.pattern, multiLine: true).allMatches(
      "import 'package:myungli_diary/features/depth/presentation/x.dart';",
    );
    expect(sample.single[1], 'depth');
    expect(sample.single[2], 'presentation');
  });
}
