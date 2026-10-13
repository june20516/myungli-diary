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
  /// 기기 파일 DB를 엽니다.
  new() : super(driftDatabase(name: 'myungli_diary'));

  /// 주어진 실행기로 엽니다. 테스트는 메모리 DB를 넘깁니다.
  new forExecutor(super.e);

  @override
  int get schemaVersion => 1;
}

/// 앱 로컬 DB. 닫는 일은 provider가 맡습니다.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
