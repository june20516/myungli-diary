// 테스트의 `Covers` 선언을 IA 계약·결정 로그와 대조해 커버리지 보고서를 만듭니다.
// 실행:
//   dart run tool/ia_coverage.dart                   보고서 쓰기
//   dart run tool/ia_coverage.dart --check           baseline보다 줄면 종료 코드 1 (쓰지 않음)
//   dart run tool/ia_coverage.dart --update-baseline 보고서와 baseline을 지금 결과로 쓰기

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const _iaPath = '../docs/ia/screens.json';
const _targetsPath = 'tool/decision_targets.json';
const _baselinePath = 'tool/coverage_baseline.json';
const _reportPath = 'docs/artifacts/e2e-coverage.json';
const _decisionLogPaths = ['../docs/decisions.md', 'docs/decisions.md'];
const _declarationRoots = ['test/flows', 'patrol_test'];

/// 선언이 잘못됐거나 IA·결정 로그에 없는 값을 가리킬 때의 오류.
class CoverageError implements Exception {
  /// 오류를 만듭니다.
  const new(this.message);

  /// 사람이 읽는 설명.
  final String message;

  @override
  String toString() => message;
}

/// 소스에서 읽은 `Covers` 선언 하나.
class CoverDeclaration {
  /// 선언을 만듭니다.
  const new({
    required this.origin,
    required this.exits,
    required this.states,
    required this.decisions,
  });

  /// `파일:줄 테스트 이름` 형태의 출처.
  final String origin;

  /// 선언한 IA 경로.
  final List<String> exits;

  /// 선언한 화면 상태.
  final List<String> states;

  /// 선언한 결정 id.
  final List<String> decisions;
}

const _testFunctions = {
  'testWidgets',
  'test',
  'patrolTest',
  'patrolWidgetTest',
};

/// [source]에서 `Covers` 생성 표현식을 모두 읽습니다. 문자열 리터럴이 아니면 [CoverageError].
List<CoverDeclaration> parseDeclarations(
  String source, {
  required String file,
}) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final visitor = _CoversVisitor(file: file, lineInfo: result.lineInfo);
  result.unit.accept(visitor);
  return visitor.declarations;
}

class _CoversVisitor extends RecursiveAstVisitor<void> {
  new({required this.file, required this.lineInfo});

  final String file;
  final LineInfo lineInfo;
  final declarations = <CoverDeclaration>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'Covers') {
      _record(node, node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  // `const` 안에서 생략된 `Covers(...)`는 해석 전에는 메서드 호출로 읽힙니다.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'Covers') {
      _record(node, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  void _record(AstNode node, ArgumentList arguments) {
    final line = lineInfo.getLocation(node.offset).lineNumber;
    final where = '$file:$line';
    final values = <String, List<String>>{};
    for (final argument in arguments.arguments) {
      if (argument is! NamedArgument) {
        throw CoverageError('$where: Covers는 이름 있는 인자만 받습니다.');
      }
      final name = argument.name.lexeme;
      if (!{'exits', 'states', 'decisions'}.contains(name)) {
        throw CoverageError('$where: 알 수 없는 인자 $name');
      }
      values[name] = _stringList(argument.argumentExpression, where);
    }
    declarations.add(
      CoverDeclaration(
        origin: '$where ${_enclosingTestName(node)}'.trim(),
        exits: values['exits'] ?? const [],
        states: values['states'] ?? const [],
        decisions: values['decisions'] ?? const [],
      ),
    );
  }

  List<String> _stringList(Expression expression, String where) {
    if (expression is! ListLiteral) {
      throw CoverageError('$where: 문자열 리터럴 목록만 쓸 수 있습니다.');
    }
    return [
      for (final element in expression.elements)
        if (element is SimpleStringLiteral)
          element.value
        else
          throw CoverageError('$where: 문자열 리터럴만 쓸 수 있습니다(변수·보간 금지).'),
    ];
  }

  String _enclosingTestName(AstNode node) {
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (parent is MethodInvocation &&
          parent.target == null &&
          _testFunctions.contains(parent.methodName.name)) {
        final first = parent.argumentList.arguments.firstOrNull;
        return first is SimpleStringLiteral ? first.value : '';
      }
    }
    return '';
  }
}

/// 한 항목 종류(경로·상태·결정)의 집계.
Map<String, Object?> _section(
  Set<String> all,
  Map<String, List<String>> coveredBy,
) {
  final covered = all.where(coveredBy.containsKey).toList()..sort();
  final uncovered = all.where((key) => !coveredBy.containsKey(key)).toList()
    ..sort();
  return {
    'covered': covered.length,
    'total': all.length,
    'uncovered': uncovered,
    'coveredBy': {for (final key in covered) key: coveredBy[key]},
  };
}

/// 선언을 IA·결정 대상과 대조해 보고서를 만듭니다.
///
/// IA에 없는 경로·상태·화면, 결정 로그에 없는 결정 id는 [CoverageError]입니다.
Map<String, Object?> buildReport({
  required Map<String, Object?> ia,
  required List<String> decisionTargets,
  required Set<String> knownDecisions,
  required List<CoverDeclaration> declarations,
  required DateTime generatedAt,
}) {
  final allExits = <String>{};
  final allStates = <String>{};
  for (final screen
      in (ia['screens']! as List<Object?>).cast<Map<String, Object?>>()) {
    final id = screen['id']! as String;
    for (final exit
        in (screen['exits']! as List<Object?>).cast<Map<String, Object?>>()) {
      allExits.add('$id>${exit['to']}');
    }
    for (final state
        in (screen['states']! as List<Object?>).cast<Map<String, Object?>>()) {
      allStates.add('$id:${state['id']}');
    }
  }
  for (final target in decisionTargets) {
    if (!knownDecisions.contains(target)) {
      throw CoverageError('decision_targets.json의 결정 $target이(가) 결정 로그에 없습니다.');
    }
  }

  final exitsBy = <String, List<String>>{};
  final statesBy = <String, List<String>>{};
  final decisionsBy = <String, List<String>>{};
  void add(
    Map<String, List<String>> into,
    String key,
    CoverDeclaration declaration,
  ) => (into[key] ??= []).add(declaration.origin);

  for (final declaration in declarations) {
    for (final exit in declaration.exits) {
      if (!allExits.contains(exit)) {
        throw CoverageError('${declaration.origin}: IA에 없는 경로 "$exit"');
      }
      add(exitsBy, exit, declaration);
    }
    for (final state in declaration.states) {
      if (!allStates.contains(state)) {
        throw CoverageError('${declaration.origin}: IA에 없는 상태 "$state"');
      }
      add(statesBy, state, declaration);
    }
    for (final decision in declaration.decisions) {
      if (!knownDecisions.contains(decision)) {
        throw CoverageError('${declaration.origin}: 결정 로그에 없는 결정 "$decision"');
      }
      // 대상이 아닌 결정은 로그에 있으면 허용하고 집계하지 않습니다.
      if (decisionTargets.contains(decision)) {
        add(decisionsBy, decision, declaration);
      }
    }
  }

  final screenIds = {
    for (final screen
        in (ia['screens']! as List<Object?>).cast<Map<String, Object?>>())
      screen['id']! as String,
  };
  Map<String, Object?> forScreen(String id) {
    Map<String, int> count(
      Set<String> all,
      Map<String, Object?> by,
      String sep,
    ) {
      final mine = all.where((key) => key.startsWith('$id$sep')).toSet();
      return {
        'covered': mine.where(by.containsKey).length,
        'total': mine.length,
      };
    }

    return {
      'exits': count(allExits, exitsBy, '>'),
      'states': count(allStates, statesBy, ':'),
    };
  }

  return {
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'exits': _section(allExits, exitsBy),
    'states': _section(allStates, statesBy),
    'decisions': _section(decisionTargets.toSet(), decisionsBy),
    'byScreen': {for (final id in screenIds) id: forScreen(id)},
  };
}

/// 보고서 covered 수가 baseline보다 줄어든 항목을 설명합니다. 줄지 않았으면 빈 목록.
List<String> findRegressions({
  required Map<String, Object?> report,
  required Map<String, Object?> baseline,
}) {
  final regressions = <String>[];
  for (final kind in ['exits', 'states', 'decisions']) {
    final now = (report[kind]! as Map<String, Object?>)['covered']! as int;
    final before = (baseline[kind]! as Map<String, Object?>)['covered']! as int;
    if (now < before) {
      regressions.add('$kind: $before → $now');
    }
  }
  return regressions;
}

/// 결정 로그 표에서 결정 id(`| D49 |`, `| A13 |`)를 모읍니다.
Set<String> parseDecisionIds(String log) => {
  for (final match in RegExp(
    r'^\|\s*([DA]\d+)\s*\|',
    multiLine: true,
  ).allMatches(log))
    match.group(1)!,
};

Future<List<CoverDeclaration>> _collectDeclarations() async {
  final declarations = <CoverDeclaration>[];
  for (final root in _declarationRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    final files =
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('_test.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      declarations.addAll(
        parseDeclarations(await file.readAsString(), file: file.path),
      );
    }
  }
  return declarations;
}

Future<Map<String, Object?>> _readJson(String path) async =>
    jsonDecode(await File(path).readAsString()) as Map<String, Object?>;

String _encode(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

String _summary(Map<String, Object?> report) {
  String line(String kind, String label) {
    final section = report[kind]! as Map<String, Object?>;
    return '$label ${section['covered']}/${section['total']}';
  }

  return '${line('exits', '경로')}, ${line('states', '상태')}, '
      '${line('decisions', '결정')}';
}

Future<int> run(List<String> args) async {
  final check = args.contains('--check');
  final updateBaseline = args.contains('--update-baseline');
  try {
    final targets = (jsonDecode(
      await File(_targetsPath).readAsString(),
    ) as List<Object?>).cast<String>();
    final known = <String>{};
    for (final path in _decisionLogPaths) {
      known.addAll(parseDecisionIds(await File(path).readAsString()));
    }
    final report = buildReport(
      ia: await _readJson(_iaPath),
      decisionTargets: targets,
      knownDecisions: known,
      declarations: await _collectDeclarations(),
      generatedAt: DateTime.now(),
    );
    if (check) {
      final baseline = await _readJson(_baselinePath);
      final regressions = findRegressions(report: report, baseline: baseline);
      if (regressions.isNotEmpty) {
        stderr.writeln('E2E 커버리지가 줄었습니다: ${regressions.join(', ')}');
        return 1;
      }
      stdout.writeln('E2E 커버리지 유지: ${_summary(report)}');
      return 0;
    }
    await File(_reportPath).create(recursive: true);
    await File(_reportPath).writeAsString(_encode(report));
    if (updateBaseline) {
      await File(_baselinePath).writeAsString(
        _encode({
          for (final kind in ['exits', 'states', 'decisions'])
            kind: {
              'covered': (report[kind]! as Map<String, Object?>)['covered'],
            },
        }),
      );
    }
    stdout.writeln('E2E 커버리지: ${_summary(report)}');
    return 0;
  } on CoverageError catch (error) {
    stderr.writeln('오류: $error');
    return 1;
  }
}

Future<void> main(List<String> args) async {
  exitCode = await run(args);
}
