// E2E 스크린샷을 app/docs/artifacts/에 복사하고 index.json에 등록합니다.
// 실행: dart run tool/register_screenshots.dart <dir> [--date YYYY-MM-DD]
//
// <dir>의 `<화면>__<상태|default>.png`를 `YYYY-MM-DD-<화면>-<상태>.png`로 복사합니다.
// 같은 화면·상태의 이전 항목은 지우지 않고 `superseded`로 바꿉니다(workflow §7).

import 'dart:convert';
import 'dart:io';

const _artifactsDir = 'docs/artifacts';
const _iaPath = '../docs/ia/screens.json';
const int _maxBytes = 2 * 1024 * 1024;
const String _milestone = 'A1';

/// 스크린샷 파일이 규칙에 맞지 않을 때의 오류.
class ScreenshotError implements Exception {
  /// 오류를 만듭니다.
  const new(this.message);

  /// 사람이 읽는 설명.
  final String message;

  @override
  String toString() => message;
}

/// `<화면>__<상태|default>.png` 이름을 (화면, 상태)로 나눕니다.
({String screen, String state}) parseScreenshotName(String fileName) {
  final match = RegExp(r'^([a-z0-9-]+)__([a-z0-9-]+)\.png$')
      .firstMatch(fileName);
  if (match == null) {
    throw ScreenshotError('파일 이름은 <화면>__<상태|default>.png여야 합니다: $fileName');
  }
  return (screen: match.group(1)!, state: match.group(2)!);
}

String _idPrefix(String screen, String state) => 'e2e.$screen.$state.';

/// [sourceDir]의 스크린샷을 [artifactsDir]에 등록하고 등록한 항목 id를 돌려줍니다.
///
/// 하나라도 규칙에 어긋나면(이름 형식, 2MB 초과, [knownScreens]에 없는 화면)
/// 아무것도 복사하지 않고 [ScreenshotError]를 던집니다.
List<String> registerScreenshots({
  required Directory sourceDir,
  required Directory artifactsDir,
  required String date,
  Set<String>? knownScreens,
}) {
  final files =
      sourceDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final parsed = <(File, String, String)>[];
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final (:screen, :state) = parseScreenshotName(name);
    if (knownScreens != null && !knownScreens.contains(screen)) {
      throw ScreenshotError('IA에 없는 화면 id: $screen ($name)');
    }
    if (file.lengthSync() > _maxBytes) {
      throw ScreenshotError('2MB를 넘습니다: $name');
    }
    parsed.add((file, screen, state));
  }

  artifactsDir.createSync(recursive: true);
  final indexFile = File('${artifactsDir.path}/index.json');
  final entries = indexFile.existsSync()
      ? (jsonDecode(indexFile.readAsStringSync()) as List<Object?>)
            .cast<Map<String, Object?>>()
      : <Map<String, Object?>>[];

  final ids = <String>[];
  for (final (file, screen, state) in parsed) {
    final id = '${_idPrefix(screen, state)}$date';
    final fileName = '$date-$screen-$state.png';
    file.copySync('${artifactsDir.path}/$fileName');

    for (final entry in entries) {
      final entryId = entry['id']! as String;
      if (entryId.startsWith(_idPrefix(screen, state)) && entryId != id) {
        if (entry['status'] == 'draft' || entry['status'] == 'chosen') {
          entry['status'] = 'superseded';
        }
      }
    }
    entries
      ..removeWhere((entry) => entry['id'] == id)
      ..add({
        'id': id,
        'title': '$screen ($state) E2E 스크린샷',
        'kind': 'screenshot',
        'file': fileName,
        'date': date,
        'milestone': _milestone,
        'screens': [screen],
        'decisions': <String>[],
        'status': 'draft',
        'note': 'Patrol E2E가 $screen 화면($state)에 도착해 남긴 캡처',
      });
    ids.add(id);
  }
  indexFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
  );
  return ids;
}

String _today() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

Future<void> main(List<String> args) async {
  final dateFlag = args.indexOf('--date');
  final date = dateFlag >= 0 ? args[dateFlag + 1] : _today();
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--date') {
      i++;
    } else {
      positional.add(args[i]);
    }
  }
  if (positional.length != 1) {
    stderr.writeln(
      '사용법: dart run tool/register_screenshots.dart <dir> [--date YYYY-MM-DD]',
    );
    exitCode = 64;
    return;
  }
  final ia =
      jsonDecode(await File(_iaPath).readAsString()) as Map<String, Object?>;
  final known = {
    for (final screen
        in (ia['screens']! as List<Object?>).cast<Map<String, Object?>>())
      screen['id']! as String,
  };
  try {
    final ids = registerScreenshots(
      sourceDir: Directory(positional.single),
      artifactsDir: Directory(_artifactsDir),
      date: date,
      knownScreens: known,
    );
    stdout.writeln('스크린샷 ${ids.length}장 등록: ${ids.join(', ')}');
  } on ScreenshotError catch (error) {
    stderr.writeln('오류: $error');
    exitCode = 1;
  }
}
