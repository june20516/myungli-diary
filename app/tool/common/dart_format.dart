// 생성기들이 함께 쓰는 `dart format` 도우미입니다. 순수 Dart만 import합니다.

import 'dart:io';

const _pubspecPath = 'pubspec.yaml';
const _analysisOptionsPath = 'analysis_options.yaml';

/// pubspec의 `environment.sdk` 하한을 `major.minor`로 돌려줍니다. 예: `^3.13.5` → `3.13`.
String dartLanguageVersion(String pubspecText) {
  final match = RegExp(
    r'''^environment:\s*\n(?:[ \t]+.*\n|\s*\n)*?[ \t]+sdk:[ \t]*['"\^>=]*(\d+)\.(\d+)''',
    multiLine: true,
  ).firstMatch(pubspecText);
  if (match == null) {
    throw StateError('pubspec.yaml에서 environment.sdk 하한을 찾지 못했습니다.');
  }
  return '${match.group(1)}.${match.group(2)}';
}

/// `dart format`을 거친 소스를 돌려줍니다. 생성 파일과 테스트가 같이 씁니다.
///
/// 임시 디렉터리에서 format하면 패키지 언어 버전을 따르지 않으므로
/// pubspec의 SDK 하한 버전을 직접 넘깁니다. `analysis_options.yaml`은 임시
/// 디렉터리에 복사해 `formatter` 설정(page_width 등)도 같게 적용합니다.
Future<String> formatDartSource(String source) async {
  final languageVersion = dartLanguageVersion(
    await File(_pubspecPath).readAsString(),
  );
  final dir = await Directory.systemTemp.createTemp('gen_format_');
  try {
    final file = File('${dir.path}/formatted.dart');
    await file.writeAsString(source);
    final options = File(_analysisOptionsPath);
    if (options.existsSync()) {
      await options.copy('${dir.path}/analysis_options.yaml');
    }
    final result = await Process.run('dart', [
      'format',
      '--language-version=$languageVersion',
      file.path,
    ]);
    if (result.exitCode != 0) {
      throw StateError('dart format 실패: ${result.stderr}');
    }
    return await file.readAsString();
  } finally {
    await dir.delete(recursive: true);
  }
}
