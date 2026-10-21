@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';

import '../../tool/common/dart_format.dart';
import '../../tool/gen_ia.dart';

void main() {
  group('iaKey', () {
    test('점과 하이픈을 단어 경계로 lowerCamelCase로 바꾼다', () {
      expect(iaKey('evidence-sheet.lock.cta'), 'evidenceSheetLockCta');
      expect(iaKey('onboard-call'), 'onboardCall');
      expect(iaKey('system-push.morning.body'), 'systemPushMorningBody');
      expect(iaKey('today'), 'today');
    });
  });

  group('generateIaSource', () {
    const smallJson = r'''
{
  "version": 1,
  "screens": [
    {
      "id": "onboard-call", "tab": null, "presentation": "half-sheet",
      "auth": "guest",
      "states": [{"id": "loading", "note": "x"}],
      "slots": [{"id": "onboard-call.head.title", "source": "ui", "role": "r"}],
      "components": ["button"],
      "exits": [{"to": "today", "trigger": "it's $done"}]
    },
    {
      "id": "today", "tab": "today", "presentation": "page", "auth": "member",
      "states": [], "slots": [], "components": [], "exits": []
    }
  ]
}
''';

    late String source;

    setUp(() {
      source = generateIaSource(jsonDecode(smallJson) as Map<String, Object?>);
    });

    test('첫 줄이 생성 안내다', () {
      expect(
        source.split('\n').first,
        '// 생성 코드: dart run tool/gen_ia.dart. 손으로 고치지 않습니다.',
      );
    });

    test('ScreenIds, SlotIds, iaScreens를 선언한다', () {
      expect(source, contains('abstract final class ScreenIds'));
      expect(
        source,
        contains("static const String onboardCall = 'onboard-call';"),
      );
      expect(source, contains("static const String today = 'today';"));
      expect(source, contains('abstract final class SlotIds'));
      expect(
        source,
        contains(
          'static const String onboardCallHeadTitle = '
          "'onboard-call.head.title';",
        ),
      );
      expect(source, contains('const List<IaScreen> iaScreens'));
      expect(source, contains('presentation: IaPresentation.halfSheet'));
      expect(source, contains('auth: IaAuth.guest'));
      expect(source, contains(r"trigger: 'it\'s \$done'"));
    });

    test('trigger의 제어 문자가 유효한 문자열 리터럴로 나온다', () {
      final json = {
        'screens': [
          {
            'id': 'a',
            'tab': null,
            'presentation': 'page',
            'auth': 'any',
            'states': <Object?>[],
            'slots': <Object?>[],
            'components': <Object?>[],
            'exits': [
              {'to': 'a', 'trigger': 'x\t\r\n\u0001\\y'},
            ],
          },
        ],
      };
      expect(generateIaSource(json), contains(r"trigger: 'x\t\r\n\u{1}\\y'"));
    });

    test('0x7F(DEL)도 이스케이프한다', () {
      final json = {
        'screens': [
          {
            'id': 'a',
            'tab': null,
            'presentation': 'page',
            'auth': 'any',
            'states': <Object?>[],
            'slots': <Object?>[],
            'components': <Object?>[],
            'exits': [
              {'to': 'a', 'trigger': 'x\u007fy'},
            ],
          },
        ],
      };
      expect(generateIaSource(json), contains(r"trigger: 'x\u{7f}y'"));
    });

    test('lowerCamelCase 이름이 겹치면 실패한다', () {
      final json = jsonDecode('''
{"screens": [
  {"id": "a-b", "tab": null, "presentation": "page", "auth": "any",
   "states": [], "slots": [{"id": "a.b"}], "components": [], "exits": []}
]}''') as Map<String, Object?>;
      expect(() => generateIaSource(json), throwsStateError);
    });
  });

  group('실제 screens.json', () {
    late Map<String, Object?> json;

    setUp(() {
      json = jsonDecode(
        File('../docs/ia/screens.json').readAsStringSync(),
      ) as Map<String, Object?>;
    });

    test('생성 상수 개수가 screens.json의 화면·슬롯 수와 같다', () {
      final screens = (json['screens']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final slotCount = screens.fold<int>(
        0,
        (sum, screen) => sum + (screen['slots']! as List<Object?>).length,
      );
      final source = generateIaSource(json);
      expect(
        RegExp('static const String').allMatches(source).length,
        screens.length + slotCount,
      );
    });

    test('커밋된 ia.g.dart가 다시 생성한 결과와 정확히 같다', () async {
      final regenerated = await formatDartSource(generateIaSource(json));
      expect(File('lib/core/ia/gen/ia.g.dart').readAsStringSync(), regenerated);
    });
  });
}
