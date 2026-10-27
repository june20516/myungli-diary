import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

/// 일기 초안. (계정, 날짜, 일기 id)당 1개이고, 새 일기는 id `''`입니다.
class DiaryDrafts extends Table {
  /// 소유 계정 id.
  TextColumn get accountId => text()();

  /// 날짜(`YYYY-MM-DD`).
  TextColumn get date => text()();

  /// 고치는 일기 id. 새 일기 초안은 빈 문자열입니다.
  TextColumn get diaryId => text().withDefault(const Constant(''))();

  /// 초안 본문.
  TextColumn get body => text()();

  /// 마지막 저장 시각(UTC).
  DateTimeColumn get updatedAt => dateTime()();

  /// 기본 키.
  @override
  Set<Column<Object>> get primaryKey => {accountId, date, diaryId};
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
  /// 위치는 [databaseDirectoryPath]입니다.
  new({String name = defaultDatabaseName})
    : super(
        driftDatabase(
          name: name,
          native: const DriftNativeOptions(
            databaseDirectory: _databaseDirectory,
          ),
        ),
      );

  /// 주어진 실행기로 엽니다. 테스트는 메모리 DB를 넘깁니다.
  new forExecutor(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 날짜 초안은 기본값 id `''`가 되어 그날 새 일기 초안으로 남습니다.
        await m.alterTable(
          TableMigration(diaryDrafts, newColumns: [diaryDrafts.diaryId]),
        );
      }
    },
  );

  /// 로그아웃 정리. 모든 계정의 캐시·일기 초안과 온보딩 입력을 지우고 기기 플래그는 남깁니다.
  ///
  /// 기기에는 한 번에 한 계정만 로그인하므로 계정 id를 몰라도(이번 실행에서 내 정보를
  /// 받기 전에 로그아웃된 경우) 이전 계정의 흔적이 다음 계정에게 보이지 않게 모두 지웁니다.
  Future<void> clearSignedOutData() => transaction(() async {
    await _deleteAccountRows();
    await delete(onboardingInputs).go();
  });

  /// 계정 데이터 정리. 모든 계정의 캐시(오늘·달력·일기 목록·나의 사주·프로필 사본)와 일기
  /// 초안을 지우고, 온보딩 입력과 기기 플래그는 남깁니다.
  ///
  /// 로그아웃 정리([clearSignedOutData])와 같은 범위에서 온보딩 입력만 뺀 것이고, 계정
  /// 합치기 뒤에 씁니다(계약 `mergeAccounts`).
  Future<void> clearAccountData() => transaction(_deleteAccountRows);

  Future<void> _deleteAccountRows() async {
    await delete(cachedResponses).go();
    await delete(diaryDrafts).go();
  }

  /// 모든 표의 행을 지웁니다. fake 모드가 시작할 때 시나리오가 섞이지 않게 씁니다.
  Future<void> clearAll() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}

/// iOS에서 DB를 두는 Application Support 아래 디렉터리 이름.
///
/// `ios/Runner/AppDelegate.swift`가 실행할 때 이 디렉터리를 만들고 iCloud·기기 백업에서
/// 뺍니다(`isExcludedFromBackup`). 일기 초안과 출생 정보가 새 기기로 옮겨지지 않게 하는
/// Android 백업 끔과 대칭입니다. 이름을 바꾸면 두 곳을 함께 고칩니다.
const iosDatabaseDirectoryName = 'Database';

/// DB 파일을 둘 디렉터리. iOS는 백업에서 뺀 전용 디렉터리, 그 밖은 drift 기본(문서
/// 디렉터리)입니다.
String databaseDirectoryPath({
  required TargetPlatform platform,
  required String applicationSupport,
  required String documents,
}) => platform == TargetPlatform.iOS
    ? '$applicationSupport/$iosDatabaseDirectoryName'
    : documents;

Future<Object> _databaseDirectory() async {
  final platform = defaultTargetPlatform;
  final path = databaseDirectoryPath(
    platform: platform,
    applicationSupport: platform == TargetPlatform.iOS
        ? (await getApplicationSupportDirectory()).path
        : '',
    documents: platform == TargetPlatform.iOS
        ? ''
        : (await getApplicationDocumentsDirectory()).path,
  );
  // AppDelegate가 먼저 만들지만, 없으면 여기서 만듭니다.
  return await Directory(path).create(recursive: true);
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
