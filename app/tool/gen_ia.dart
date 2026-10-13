// IA 계약(../docs/ia/screens.json)을 Dart 상수로 생성합니다.
// 실행: dart run tool/gen_ia.dart

import 'dart:convert';
import 'dart:io';

import 'package:myungli_diary/core/ia/ia_model.dart';

import 'common/dart_format.dart';

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

  // 화면 id와 슬롯 id를 한 집합으로 검사한다. IA 어휘 전체에서 lowerCamelCase 이름이 유일하도록 보수적으로 지킨다.
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

/// Dart 작은따옴표 문자열 리터럴로 만듭니다. 제어 문자는 이스케이프합니다.
String _quote(String value) {
  final escaped = value.runes.map((rune) {
    return switch (rune) {
      0x5C => r'\\',
      0x27 => r"\'",
      0x24 => r'\$',
      0x0A => r'\n',
      0x0D => r'\r',
      0x09 => r'\t',
      < 0x20 || 0x7F => '\\u{${rune.toRadixString(16)}}',
      _ => String.fromCharCode(rune),
    };
  }).join();
  return "'$escaped'";
}

Future<void> main() async {
  final decoded = jsonDecode(await File(_inputPath).readAsString());
  final source = await formatDartSource(
    generateIaSource(decoded as Map<String, Object?>),
  );

  final output = File(_outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(source);
}
