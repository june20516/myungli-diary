import 'package:flutter_test/flutter_test.dart';

import '../../tool/ia_coverage.dart';

void main() {
  final ia = <String, Object?>{
    'screens': [
      {
        'id': 'launch',
        'states': [
          {'id': 'loading'},
          {'id': 'offline'},
        ],
        'exits': [
          {'to': 'today'},
          {'to': 'welcome'},
        ],
      },
      {
        'id': 'welcome',
        'states': <Object?>[],
        'exits': [
          {'to': 'onboard-call'},
        ],
      },
    ],
  };
  const known = {'D49', 'D50', 'D99', 'A13'};

  Map<String, Object?> build(List<CoverDeclaration> declarations) =>
      buildReport(
        ia: ia,
        decisionTargets: const ['D49', 'D50'],
        knownDecisions: known,
        declarations: declarations,
        generatedAt: DateTime.utc(2026, 10, 14),
      );

  CoverDeclaration declaration({
    List<String> exits = const [],
    List<String> states = const [],
    List<String> decisions = const [],
  }) => CoverDeclaration(
    origin: 'x_test.dart:1 시험',
    exits: exits,
    states: states,
    decisions: decisions,
  );

  group('buildReport', () {
    test('선언 2개로 covered와 uncovered가 맞습니다', () {
      final report = build([
        declaration(exits: ['launch>welcome'], decisions: ['D50']),
        declaration(states: ['launch:offline'], decisions: ['D99']),
      ]);

      final exits = report['exits']! as Map<String, Object?>;
      expect(exits['covered'], 1);
      expect(exits['total'], 3);
      expect(exits['uncovered'], ['launch>today', 'welcome>onboard-call']);
      final states = report['states']! as Map<String, Object?>;
      expect(states['covered'], 1);
      expect(states['uncovered'], ['launch:loading']);
      final decisions = report['decisions']! as Map<String, Object?>;
      expect(decisions['covered'], 1, reason: 'D99는 대상이 아닙니다');
      expect(decisions['uncovered'], ['D49']);
      expect(report['byScreen'], {
        'launch': {
          'exits': {'covered': 1, 'total': 2},
          'states': {'covered': 1, 'total': 2},
        },
        'welcome': {
          'exits': {'covered': 0, 'total': 1},
          'states': {'covered': 0, 'total': 0},
        },
      });
    });

    test('없는 화면·경로·상태·결정 id는 오류입니다', () {
      expect(
        () => build([
          declaration(exits: ['nowhere>welcome']),
        ]),
        throwsA(isA<CoverageError>()),
      );
      expect(
        () => build([
          declaration(exits: ['launch>onboard-call']),
        ]),
        throwsA(isA<CoverageError>()),
      );
      expect(
        () => build([
          declaration(states: ['launch:missing']),
        ]),
        throwsA(isA<CoverageError>()),
      );
      expect(
        () => build([
          declaration(decisions: ['D777']),
        ]),
        throwsA(isA<CoverageError>()),
      );
    });
  });

  group('findRegressions', () {
    Map<String, Object?> counts(int exits, int states, int decisions) => {
      'exits': {'covered': exits},
      'states': {'covered': states},
      'decisions': {'covered': decisions},
    };

    test('baseline보다 줄면 알려 주고 같거나 늘면 비웁니다', () {
      expect(
        findRegressions(report: counts(1, 2, 3), baseline: counts(2, 2, 3)),
        ['exits: 2 → 1'],
      );
      expect(
        findRegressions(report: counts(3, 2, 4), baseline: counts(2, 2, 3)),
        isEmpty,
      );
    });
  });

  group('parseDeclarations', () {
    test('const Covers와 const 안에서 생략된 Covers를 읽고 테스트 이름을 붙입니다', () {
      final declarations = parseDeclarations('''
void main() {
  const mapped = {'a': (1, Covers(exits: ['launch>today']))};
  testWidgets('도착합니다', (tester) async {
    covers(const Covers(exits: ['launch>welcome'], decisions: ['D50']));
  });
}
''', file: 'a_test.dart');

      expect(declarations, hasLength(2));
      expect(declarations[0].exits, ['launch>today']);
      expect(declarations[1].exits, ['launch>welcome']);
      expect(declarations[1].decisions, ['D50']);
      expect(declarations[1].origin, 'a_test.dart:4 도착합니다');
    });

    test('변수나 보간은 오류입니다', () {
      expect(
        () => parseDeclarations(
          'final x = Covers(exits: [path]);',
          file: 'a_test.dart',
        ),
        throwsA(isA<CoverageError>()),
      );
      expect(
        () => parseDeclarations(
          r"final x = Covers(exits: ['a>$b']);",
          file: 'a_test.dart',
        ),
        throwsA(isA<CoverageError>()),
      );
    });
  });

  test('parseDecisionIds는 결정 로그 표의 id를 읽습니다', () {
    expect(parseDecisionIds('| D49 | 2026 | x |\n| A13 | y |\n본문 D50'), {
      'D49',
      'A13',
    });
  });
}
