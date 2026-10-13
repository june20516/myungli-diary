import 'package:flutter_test/flutter_test.dart';

import '../../tool/common/dart_format.dart';

void main() {
  group('dartLanguageVersion', () {
    test('environment.sdk 하한의 major.minor를 돌려준다', () {
      const pubspec = '''
name: x
environment:
  sdk: ^3.13.5

dependencies:
  flutter:
    sdk: flutter
''';
      expect(dartLanguageVersion(pubspec), '3.13');
    });

    test('범위 표기와 주석 줄이 있어도 읽는다', () {
      const pubspec = '''
environment:
  # 주석
  sdk: '>=3.9.0 <4.0.0'
''';
      expect(dartLanguageVersion(pubspec), '3.9');
    });

    test('environment.sdk가 없으면 실패한다', () {
      expect(() => dartLanguageVersion('name: x\n'), throwsStateError);
    });
  });

  test('formatDartSource가 소스를 정리한다', () async {
    expect(await formatDartSource('void main(){}'), 'void main() {}\n');
  });
}
