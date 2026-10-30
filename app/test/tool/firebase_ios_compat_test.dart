import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `pubspec.lock`에서 [package]의 버전 주 번호.
int _majorOf(String lock, String package) {
  final match = RegExp(
    '^  $package:\\n(?:    .*\\n)*?    version: "(\\d+)\\.',
    multiLine: true,
  ).firstMatch(lock);
  if (match == null) throw StateError('$package가 pubspec.lock에 없습니다');
  return int.parse(match.group(1)!);
}

/// iOS SPM에서 함께 풀리는 조합인지(A96).
///
/// `firebase_core` 5 이상(iOS SDK 13, `gtm-session-fetcher` 4 이상)은
/// `google_sign_in_ios` 6.x(GoogleSignIn 9.x, `gtm-session-fetcher` 3.x)와
/// 함께 풀리지 않습니다. CI는 iOS를 빌드하지 않아 이 검사가 대신 막습니다.
bool _iosResolvable(String lock) =>
    _majorOf(lock, 'firebase_core') < 5 ||
    _majorOf(lock, 'google_sign_in_ios') >= 7;

String _lockWith({required String core, required String googleIos}) =>
    '''
packages:
  firebase_core:
    dependency: "direct main"
    source: hosted
    version: "$core"
  google_sign_in_ios:
    dependency: transitive
    source: hosted
    version: "$googleIos"
''';

void main() {
  test('pubspec.lock의 Firebase와 Google 로그인 iOS 조합이 함께 풀립니다(A96)', () {
    final lock = File('pubspec.lock').readAsStringSync();
    expect(
      _iosResolvable(lock),
      isTrue,
      reason:
          'firebase_core 5 이상은 google_sign_in_ios가 GoogleSignIn 10 이상을 '
          '받기 전에는 iOS 빌드가 깨집니다(A96). 올렸다면 flutter build ios로 '
          '확인하고 이 검사를 고치세요.',
    );
  });

  test('충돌 조합을 잡습니다', () {
    expect(
      _iosResolvable(_lockWith(core: '5.1.0', googleIos: '6.3.8')),
      isFalse,
    );
    expect(
      _iosResolvable(_lockWith(core: '4.15.2', googleIos: '6.3.8')),
      isTrue,
    );
  });
}
