// 화면 스크린샷을 app/docs/artifacts/에 복사하고 index.json에 등록합니다.
// 실행: dart run tool/register_screenshots.dart <dir> [--date YYYY-MM-DD]
//        [--decisions D50,D49] [--source <원본 파일 이름>] [--origin e2e|render]
//
// <dir>의 `<화면>__<상태|default>.png`를 `YYYY-MM-DD-<화면>-<상태>.png`로 복사합니다.
// * `e2e`(기본, Patrol 캡처): 같은 화면·상태의 이전 항목은 지우지 않고 `superseded`로 바꿉니다
//   (workflow §7).
// * `render`(tool/screens_linux.sh가 대역 데이터로 그린 화면, #336): 언제든 다시 만들 수 있으므로
//   같은 화면·상태의 이전 렌더는 파일까지 지우고, 이전과 바이트가 같으면 새로 등록하지 않습니다
//   (공개 저장소가 같은 그림으로 커지지 않게). 이번 입력에 없는 화면·상태의 `render.*` 항목과
//   파일도 지웁니다. 그래서 <dir>은 사례 전체를 그린 결과(`build/screens`)여야 합니다.

import 'dart:convert';
import 'dart:io';

import 'ia_coverage.dart' show parseDecisionIds;

const _artifactsDir = 'docs/artifacts';
const _iaPath = '../docs/ia/screens.json';
const int _maxBytes = 2 * 1024 * 1024;
const _decisionLogPaths = ['../docs/decisions.md', 'docs/decisions.md'];
const String _milestone = 'A1';

/// 스크린샷의 출처.
enum ScreenshotOrigin {
  /// Patrol E2E 캡처.
  e2e,

  /// 대역 데이터로 그린 화면(tool/screens_linux.sh).
  render,
}

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

String _idPrefix(ScreenshotOrigin origin, String screen, String state) =>
    '${origin.name}.$screen.$state.';

/// [sourceDir]의 스크린샷을 [artifactsDir]에 등록하고 등록한 항목 id를 돌려줍니다.
///
/// 하나라도 규칙에 어긋나면(이름 형식, 2MB 초과, [knownScreens]에 없는 화면)
/// 아무것도 복사하지 않고 [ScreenshotError]를 던집니다.
List<String> registerScreenshots({
  required Directory sourceDir,
  required Directory artifactsDir,
  required String date,
  Set<String>? knownScreens,
  List<String> decisions = const [],
  Set<String>? knownDecisions,
  String? source,
  ScreenshotOrigin origin = ScreenshotOrigin.e2e,
}) {
  for (final decision in decisions) {
    if (knownDecisions != null && !knownDecisions.contains(decision)) {
      throw ScreenshotError('결정 로그에 없는 결정 id: $decision');
    }
  }
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
    final prefix = _idPrefix(origin, screen, state);
    final id = '$prefix$date';
    final fileName = '$date-$screen-$state.png';
    final bytes = file.readAsBytesSync();

    if (origin == ScreenshotOrigin.render) {
      final previous = [
        for (final entry in entries)
          if ((entry['id']! as String).startsWith(prefix)) entry,
      ];
      // 같은 그림이 이미 등록돼 있으면 그대로 둡니다.
      final same = previous.any((entry) {
        final old = File('${artifactsDir.path}/${entry['file']}');
        return old.existsSync() && _sameBytes(old.readAsBytesSync(), bytes);
      });
      if (same) {
        continue;
      }
      for (final entry in previous) {
        final old = File('${artifactsDir.path}/${entry['file']}');
        if (entry['file'] != fileName && old.existsSync()) {
          old.deleteSync();
        }
        entries.remove(entry);
      }
      file.copySync('${artifactsDir.path}/$fileName');
      entries.add({
        'id': id,
        'title': '$screen ($state) 화면',
        'kind': 'screenshot',
        'file': fileName,
        'source': ?source,
        'date': date,
        'milestone': _milestone,
        'screens': [screen],
        'decisions': decisions,
        'status': 'draft',
        'note': '$state 상태. 대역 데이터로 그린 화면(tool/screens_linux.sh)',
      });
      ids.add(id);
      continue;
    }

    file.copySync('${artifactsDir.path}/$fileName');

    // 더 최신 항목은 건드리지 않고, 이전 날짜 항목만 대체합니다.
    var hasNewer = false;
    for (final entry in entries) {
      final entryId = entry['id']! as String;
      if (!entryId.startsWith(prefix) || entryId == id) {
        continue;
      }
      if ((entry['date']! as String).compareTo(date) > 0) {
        hasNewer = true;
      } else if (entry['status'] == 'draft' || entry['status'] == 'chosen') {
        entry['status'] = 'superseded';
      }
    }
    entries
      ..removeWhere((entry) => entry['id'] == id)
      ..add({
        'id': id,
        'title': '$screen ($state) E2E 스크린샷',
        'kind': 'screenshot',
        'file': fileName,
        'source': ?source,
        'date': date,
        'milestone': _milestone,
        'screens': [screen],
        'decisions': decisions,
        'status': hasNewer ? 'superseded' : 'draft',
        'note': 'Patrol E2E가 $screen 화면($state)에 도착해 남긴 캡처',
      });
    ids.add(id);
  }
  if (origin == ScreenshotOrigin.render) {
    _dropOrphanRenders(entries, artifactsDir, {
      for (final (_, screen, state) in parsed)
        _idPrefix(ScreenshotOrigin.render, screen, state),
    });
  }
  // 화면·상태 순으로 정렬해 diff가 흔들리지 않게 합니다.
  entries.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  indexFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
  );
  return ids;
}

/// 이번 렌더 입력([kept] 접두어)에 없는 화면·상태의 `render.*` 항목과 그 파일을 지웁니다.
///
/// 렌더는 `screens_test.dart`가 모든 사례를 한 번에 그린 결과이고 언제든 다시 만들 수 있으므로,
/// 사례가 빠지거나 이름이 바뀐 그림이 공개 저장소에 고아로 남지 않게 합니다. Patrol 캡처(`e2e.*`)는
/// 기록이라 건드리지 않습니다.
void _dropOrphanRenders(
  List<Map<String, Object?>> entries,
  Directory artifactsDir,
  Set<String> kept,
) {
  final renderPrefix = '${ScreenshotOrigin.render.name}.';
  final orphans = [
    for (final entry in entries)
      if (entry['id'] case final String id
          when id.startsWith(renderPrefix) && !kept.any(id.startsWith))
        entry,
  ];
  for (final entry in orphans) {
    final file = File('${artifactsDir.path}/${entry['file']}');
    if (file.existsSync()) {
      file.deleteSync();
    }
    entries.remove(entry);
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _today() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      if (i + 1 >= args.length) {
        stderr.writeln('${args[i]}에 값이 없습니다.');
        exitCode = 64;
        return;
      }
      options[args[i]] = args[++i];
    } else {
      positional.add(args[i]);
    }
  }
  final unknown = options.keys.where(
    (key) =>
        !const {'--date', '--decisions', '--source', '--origin'}.contains(key),
  );
  final originName = options['--origin'] ?? ScreenshotOrigin.e2e.name;
  final origin = ScreenshotOrigin.values
      .where((value) => value.name == originName)
      .firstOrNull;
  if (positional.length != 1 || unknown.isNotEmpty || origin == null) {
    stderr.writeln(
      '사용법: dart run tool/register_screenshots.dart <dir> '
      '[--date YYYY-MM-DD] [--decisions D50,D49] [--source <파일>] '
      '[--origin e2e|render]',
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
  final knownDecisions = <String>{};
  for (final path in _decisionLogPaths) {
    knownDecisions.addAll(parseDecisionIds(await File(path).readAsString()));
  }
  try {
    final ids = registerScreenshots(
      sourceDir: Directory(positional.single),
      artifactsDir: Directory(_artifactsDir),
      date: options['--date'] ?? _today(),
      knownScreens: known,
      decisions: (options['--decisions'] ?? '')
          .split(',')
          .where((id) => id.isNotEmpty)
          .toList(),
      knownDecisions: knownDecisions,
      source: options['--source'],
      origin: origin,
    );
    stdout.writeln('스크린샷 ${ids.length}장 등록: ${ids.join(', ')}');
  } on ScreenshotError catch (error) {
    stderr.writeln('오류: $error');
    exitCode = 1;
  }
}
