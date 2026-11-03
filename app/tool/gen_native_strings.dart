// ARB 원고에서 OS가 직접 보여 주는 문구(홈 화면 앱 이름, iOS 권한 창)를 생성합니다(결정 A101).
//   ios/Runner/<en|ko|ja>.lproj/InfoPlist.strings, Info.plist 기본값(en)
//   android/app/src/main/res/values(-ko, -ja)/strings.xml
// 실행: dart run tool/gen_native_strings.dart
// 검사: dart run tool/gen_native_strings.dart --check (파일을 쓰지 않고, 다르면 종료 코드 1)

import 'dart:io';

import 'common/native_strings.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final expected = renderNativeStrings();
  final stale = [
    for (final MapEntry(key: path, value: content) in expected.entries)
      if (!File(path).existsSync() || File(path).readAsStringSync() != content)
        path,
  ];
  if (check) {
    if (stale.isNotEmpty) {
      stderr.writeln(
        '${stale.join(', ')}가 ARB와 다릅니다. '
        'dart run tool/gen_native_strings.dart로 다시 만드세요.',
      );
      exitCode = 1;
    }
    return;
  }
  for (final path in stale) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(expected[path]!);
    stdout.writeln('$path를 만들었습니다.');
  }
}
