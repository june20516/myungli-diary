import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/common/native_strings.dart';

/// OS가 보여 주는 문구(앱 이름, iOS 권한 창)가 ARB 원고와 같은지 확인합니다(결정 A101).
void main() {
  group('escape', () {
    test('.strings 값은 역슬래시, 따옴표, 줄바꿈을 escape합니다', () {
      expect(escapeStringsValue('a\\b "c"\nd'), r'a\\b \"c\"\nd');
    });

    test('Android 값은 XML 특수 문자와 작은따옴표도 escape합니다', () {
      expect(escapeAndroidValue("Don't <b>&"), r"Don\'t &lt;b&gt;&amp;");
    });

    test('plist 값은 XML 특수 문자를 escape합니다', () {
      expect(escapePlistValue('a & <b>'), 'a &amp; &lt;b&gt;');
    });
  });

  test('Info.plist 키가 없으면 던집니다', () {
    expect(
      () => applyInfoPlistStrings('<dict></dict>', {
        'CFBundleDisplayName': 'x',
        'NSUserTrackingUsageDescription': 'y',
      }),
      throwsStateError,
    );
  });

  test('커밋된 InfoPlist.strings, strings.xml, Info.plist 기본값이 '
      'ARB에서 만든 것과 같습니다', () {
    for (final MapEntry(key: path, value: expected)
        in renderNativeStrings().entries) {
      expect(
        File(path).readAsStringSync(),
        expected,
        reason: '$path: dart run tool/gen_native_strings.dart',
      );
    }
  });

  test('앱 이름은 writing W17 값입니다', () {
    expect(readNativeStrings('ko', androidStringKeys)['app_name'], '명리일기');
    expect(
      readNativeStrings('en', androidStringKeys)['app_name'],
      'Myungli Diary',
    );
    expect(readNativeStrings('ja', androidStringKeys)['app_name'], '命理日記');
  });

  test('Info.plist가 세 언어를 선언하고 수출 규정 면제를 밝힙니다', () {
    final plist = File(infoPlistPath).readAsStringSync();
    expect(
      plist,
      matches(
        RegExp(
          r'<key>CFBundleLocalizations</key>\s*<array>\s*'
          r'<string>en</string>\s*<string>ko</string>\s*<string>ja</string>',
        ),
      ),
    );
    expect(
      plist,
      matches(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')),
    );
  });

  test('AndroidManifest 앱 이름은 문자열 리소스를 씁니다', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="@string/app_name"'),
    );
  });
}
