import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// server 응답 캐시. 키는 (계정, 종류, 캐시 키)입니다.
class CachedResponses extends Table {
  /// 소유 계정 id.
  TextColumn get accountId => text()();

  /// `CacheKind.name`.
  TextColumn get kind => text()();

  /// 종류 안의 캐시 키.
  TextColumn get cacheKey => text()();

  /// 저장한 JSON 본문.
  TextColumn get json => text()();

  /// 응답을 만든 규칙 버전. 없는 응답은 null입니다.
  TextColumn get rulesetVersion => text().nullable()();

  /// `EvidenceAccess.value`.
  TextColumn get evidenceAccess => text()();

  /// 받은 시각(UTC).
  DateTimeColumn get fetchedAt => dateTime()();

  /// 기본 키.
  @override
  Set<Column<Object>> get primaryKey => {accountId, kind, cacheKey};
}

/// 일기 초안. 날짜(`YYYY-MM-DD`)당 1개입니다.
class DiaryDrafts extends Table {
  /// 소유 계정 id.
  TextColumn get accountId => text()();

  /// 날짜(`YYYY-MM-DD`).
  TextColumn get date => text()();

  /// 초안 본문.
  TextColumn get body => text()();

  /// 마지막 저장 시각(UTC).
  DateTimeColumn get updatedAt => dateTime()();

  /// 기본 키.
  @override
  Set<Column<Object>> get primaryKey => {accountId, date};
}

/// 온보딩 입력. 로그인 전에 쓰므로 계정 없는 단일 행(id=1)입니다.
class OnboardingInputs extends Table {
  /// 항상 1입니다.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// 저장한 JSON 본문.
  TextColumn get json => text()();

  /// 마지막 저장 시각(UTC).
  DateTimeColumn get updatedAt => dateTime()();

  /// 기본 키.
  @override
  Set<Column<Object>> get primaryKey => {id};

  /// id가 1인 행만 허용합니다.
  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

/// 기기 단위 플래그(광고 동의, 규칙 버전 등). 계정과 무관합니다.
class DeviceFlags extends Table {
  /// 플래그 이름.
  TextColumn get key => text()();

  /// 플래그 값.
  TextColumn get value => text()();

  /// 기본 키.
  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 앱 로컬 DB(drift/SQLite).
@DriftDatabase(
  tables: [CachedResponses, DiaryDrafts, OnboardingInputs, DeviceFlags],
)
class AppDatabase extends _$AppDatabase {
  /// 기기 파일 DB를 엽니다. [name]이 다르면 다른 파일입니다(fake 모드는 운영과 분리).
  new({String name = defaultDatabaseName}) : super(driftDatabase(name: name));

  /// 주어진 실행기로 엽니다. 테스트는 메모리 DB를 넘깁니다.
  new forExecutor(super.e);

  @override
  int get schemaVersion => 1;

  /// 모든 표의 행을 지웁니다. fake 모드가 시작할 때 시나리오가 섞이지 않게 씁니다.
  Future<void> clearAll() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}

/// 운영 DB 파일 이름.
const defaultDatabaseName = 'myungli_diary';

/// 열 DB 파일 이름. fake 모드가 운영 DB와 분리하려고 override합니다.
final databaseNameProvider = Provider<String>((ref) => defaultDatabaseName);

/// 앱 로컬 DB. 닫는 일은 provider가 맡습니다.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(name: ref.watch(databaseNameProvider));
  ref.onDispose(database.close);
  return database;
});
