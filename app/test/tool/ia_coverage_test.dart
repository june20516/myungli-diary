@Tags(['contract'])
library;

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

    test('경로가 줄면 알려 주고 같거나 늘면 비웁니다', () {
      expect(
        findRegressions(report: counts(1, 2, 3), baseline: counts(2, 2, 3)),
        ['exits: 2 → 1'],
      );
      expect(
        findRegressions(report: counts(3, 2, 4), baseline: counts(2, 2, 3)),
        isEmpty,
      );
    });

    test('상태가 줄면 알려 줍니다', () {
      expect(
        findRegressions(report: counts(2, 1, 3), baseline: counts(2, 2, 3)),
        ['states: 2 → 1'],
      );
    });

    test('결정이 줄면 알려 줍니다', () {
      expect(
        findRegressions(report: counts(2, 2, 2), baseline: counts(2, 2, 3)),
        ['decisions: 3 → 2'],
      );
    });

    test('baseline에 키가 없으면 어느 키인지 담은 오류입니다', () {
      expect(
        () => findRegressions(
          report: counts(1, 1, 1),
          baseline: {
            'exits': {'covered': 1},
            'decisions': {'covered': 1},
          },
        ),
        throwsA(
          isA<CoverageError>().having(
            (error) => error.message,
            'message',
            allOf(contains('states'), contains('coverage_baseline.json')),
          ),
        ),
      );
    });
  });

  group('parseDeclarations', () {
    test('covers(const Covers) 선언을 읽고 테스트 이름을 붙입니다', () {
      final declarations = parseDeclarations('''
void main() {
  testWidgets('도착합니다', (tester) async {
    covers(const Covers(exits: ['launch>welcome'], decisions: ['D50']));
  });
  test('빈 선언', () {
    covers(const Covers());
  });
}
''', file: 'a_test.dart');

      expect(declarations, hasLength(2));
      expect(declarations[0].exits, ['launch>welcome']);
      expect(declarations[0].decisions, ['D50']);
      expect(declarations[0].origin, 'a_test.dart:3 도착합니다');
      expect(declarations[1].exits, isEmpty);
    });

    void expectError(String body) => expect(
      () => parseDeclarations(body, file: 'a_test.dart'),
      throwsA(isA<CoverageError>()),
      reason: body,
    );

    test('변수나 보간은 오류입니다', () {
      expectError('void f() { covers(const Covers(exits: [path])); }');
      expectError(r"void f() { covers(const Covers(exits: ['a>$b'])); }");
    });

    test('covers() 밖의 Covers(맵·변수·const 생략)는 오류입니다', () {
      expectError("final x = {'a': (1, Covers(exits: ['launch>today']))};");
      expectError("const x = Covers(exits: ['launch>today']);");
      expectError("void f() { covers(Covers(exits: ['launch>today'])); }");
    });

    test('접두어 import와 문법 오류는 오류입니다', () {
      expectError('void f() { p.covers(const Covers()); }');
      expectError('void f() { covers(const p.Covers()); }');
      expectError('void f() { covers(const Covers(exits: [ );');
    });
  });

  test('parseDecisionIds는 결정 로그 표의 id를 읽습니다', () {
    expect(parseDecisionIds('| D49 | 2026 | x |\n| A13 | y |\n본문 D50'), {
      'D49',
      'A13',
    });
  });
}
