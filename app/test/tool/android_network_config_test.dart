import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 로컬 server용 평문 http 허용이 debug 빌드 밖으로 새지 않는지 확인합니다.
void main() {
  test('main manifest는 평문 http를 허용하지 않습니다', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, isNot(contains('usesCleartextTraffic')));
    expect(manifest, isNot(contains('networkSecurityConfig')));
    expect(
      File('android/app/src/main/res/xml/network_security_config.xml')
          .existsSync(),
      isFalse,
    );
  });

  test('debug 설정은 localhost와 127.0.0.1에만 평문 http를 허용합니다', () {
    final config = File(
      'android/app/src/debug/res/xml/network_security_config.xml',
    ).readAsStringSync();
    final domains = RegExp('<domain[^>]*>([^<]+)</domain>')
        .allMatches(config)
        .map((match) => match.group(1))
        .toList();
    expect(domains, ['localhost', '127.0.0.1']);
    expect(config, isNot(contains('base-config')));
  });
}
