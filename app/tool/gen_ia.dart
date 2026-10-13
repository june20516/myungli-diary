// IA 계약(../docs/ia/screens.json)을 Dart 상수로 생성합니다.
// 실행: dart run tool/gen_ia.dart

import 'dart:convert';
import 'dart:io';

import 'package:myungli_diary/core/ia/ia_model.dart';

const _inputPath = '../docs/ia/screens.json';
const _outputPath = 'lib/core/ia/gen/ia.g.dart';

/// screens.json 내용(디코딩 결과)에서 생성 코드 소스를 만듭니다.
String generateIaSource(Map<String, Object?> json) {
  final screens = (json['screens']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final slotIds = [
    for (final screen in screens)
      for (final slot in (screen['slots'] as List<Object?>? ?? const []))
        (slot! as Map<String, Object?>)['id']! as String,
  ];
  final screenIds = [for (final screen in screens) screen['id']! as String];

  _checkUniqueKeys([...screenIds, ...slotIds]);

  final out = StringBuffer()
    ..writeln('// 생성 코드: dart run tool/gen_ia.dart. 손으로 고치지 않습니다.')
    ..writeln()
    ..writeln("import 'package:myungli_diary/core/ia/ia_model.dart';")
    ..writeln()
    ..writeln('/// 화면 id 상수.')
    ..writeln('abstract final class ScreenIds {');
  for (final id in screenIds) {
    out.writeln("static const String ${iaKey(id)} = '$id';");
  }
  out
    ..writeln('}')
    ..writeln()
    ..writeln('/// 슬롯 id 상수.')
    ..writeln('abstract final class SlotIds {');
  for (final id in slotIds) {
    out.writeln("static const String ${iaKey(id)} = '$id';");
  }
  out
    ..writeln('}')
    ..writeln()
    ..writeln('/// IA 화면 목록.')
    ..writeln('const List<IaScreen> iaScreens = [');
  for (final screen in screens) {
    out.writeln(_screenSource(screen));
  }
  out.writeln('];');
  return out.toString();
}

/// id가 lowerCamelCase로 바뀐 뒤에도 겹치지 않는지 확인합니다.
void _checkUniqueKeys(List<String> ids) {
  final byKey = <String, String>{};
  for (final id in ids) {
    final key = iaKey(id);
    final previous = byKey[key];
    if (previous != null) {
      throw StateError("id '$previous'와 '$id'가 같은 이름 '$key'가 됩니다.");
    }
    byKey[key] = id;
  }
}

String _screenSource(Map<String, Object?> screen) {
  final tab = screen['tab'] as String?;
  final presentation = IaPresentation.fromJson(
    screen['presentation']! as String,
  );
  final auth = IaAuth.fromJson(screen['auth']! as String);
  final states = [
    for (final state in screen['states']! as List<Object?>)
      (state! as Map<String, Object?>)['id']! as String,
  ];
  final exits = (screen['exits']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final components = (screen['components']! as List<Object?>).cast<String>();

  return '''
IaScreen(
  id: ${_quote(screen['id']! as String)},
  tab: ${tab == null ? 'null' : _quote(tab)},
  presentation: IaPresentation.${presentation.name},
  auth: IaAuth.${auth.name},
  states: ${_stringList(states)},
  exits: [
    ${[for (final exit in exits) 'IaExit(to: ${_quote(exit['to']! as String)}, trigger: ${_quote(exit['trigger']! as String)}),'].join('\n')}
  ],
  components: ${_stringList(components)},
),''';
}

String _stringList(List<String> values) => '[${values.map(_quote).join(', ')}]';

/// Dart 작은따옴표 문자열 리터럴로 만듭니다.
String _quote(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}

Future<void> main() async {
  final decoded = jsonDecode(await File(_inputPath).readAsString());
  final source = generateIaSource(decoded as Map<String, Object?>);

  final output = File(_outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(source);

  final format = await Process.run('dart', ['format', _outputPath]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stderr);
    exit(format.exitCode);
  }
}
