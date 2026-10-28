// config/auth.json(A81)에서 ios/Flutter/Auth.xcconfig를 생성합니다.
// 실행: dart run tool/gen_native_config.dart
// 검사: dart run tool/gen_native_config.dart --check (파일을 쓰지 않고, 다르면 종료 코드 1)

import 'dart:io';

import 'common/native_auth_config.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final expected = renderAuthXcconfig(readAuthConfigJson(File(authConfigPath)));
  final output = File(authXcconfigPath);
  final actual = output.existsSync() ? output.readAsStringSync() : null;
  if (check) {
    if (actual != expected) {
      stderr.writeln(
        '$authXcconfigPath가 $authConfigPath와 다릅니다. '
        'dart run tool/gen_native_config.dart로 다시 만드세요.',
      );
      exitCode = 1;
    }
    return;
  }
  output.writeAsStringSync(expected);
  stdout.writeln('$authXcconfigPath를 만들었습니다.');
}
