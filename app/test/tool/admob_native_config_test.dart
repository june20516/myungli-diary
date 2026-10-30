import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AdMob 앱 ID(#686, 결정 A99)가 native 설정에 있는지 확인합니다. 없으면 SDK가 앱 시작
/// 때 종료합니다. 앱 ID는 빌드 모드와 상관없이 실제 값입니다.
void main() {
  test('AndroidManifest에 AdMob Android 앱 ID', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      manifest,
      contains('android:name="com.google.android.gms.ads.APPLICATION_ID"'),
    );
    expect(
      manifest,
      contains('android:value="ca-app-pub-5703509220233743~1675843971"'),
    );
  });

  test('Info.plist에 AdMob iOS 앱 ID와 Google SKAdNetwork', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      plist,
      matches(
        RegExp(
          r'<key>GADApplicationIdentifier</key>\s*'
          '<string>ca-app-pub-5703509220233743~7355546068</string>',
        ),
      ),
    );
    expect(plist, contains('<string>cstr6suwn9.skadnetwork</string>'));
  });
}
