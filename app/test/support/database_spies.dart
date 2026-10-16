import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor;

/// 실행한 쓰기 SQL(INSERT·DELETE)을 순서대로 남깁니다. 쓰기 순서를 확인할 때 씁니다.
final class StatementLog extends QueryInterceptor {
  /// 실행한 SQL.
  final statements = <String>[];

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    return super.runDelete(executor, statement, args);
  }
}

/// [failing]이 켜지면 [table]로의 INSERT를 실패시킵니다. [arg]가 있으면 그 값이 인자에
/// 있는 INSERT만 실패시킵니다(예: 캐시 종류 `daily`).
final class FailingInserts extends QueryInterceptor {
  /// [table]로의 INSERT를 실패시킬 준비를 합니다.
  new(this.table, {this.arg});

  /// 실패시킬 테이블 이름.
  final String table;

  /// 실패시킬 INSERT의 인자 값. null이면 모든 INSERT.
  final Object? arg;

  /// true일 때만 실패시킵니다.
  bool failing = false;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (failing &&
        statement.contains(table) &&
        (arg == null || args.contains(arg))) {
      throw StateError('테스트: $table 쓰기 실패');
    }
    return super.runInsert(executor, statement, args);
  }
}
