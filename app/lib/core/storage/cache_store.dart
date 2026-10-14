import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

/// 캐시 종류.
enum CacheKind {
  /// 달력(사주 기반, 영구).
  calendar,

  /// 나의 사주(사주 기반, 영구).
  chart,

  /// 오늘(날짜가 키, 마지막 응답을 오프라인용으로 남김).
  daily,

  /// 용어집.
  glossary,

  /// 프로필 저장 응답의 사본(키 하나, 결정 A18).
  profile,
}

const _keySeparator = '|';

/// 달력 캐시 키. 월은 두 자리로 맞춥니다.
String calendarKey({
  required String fingerprint,
  required String language,
  required int year,
  required int month,
}) {
  final paddedMonth = month.toString().padLeft(2, '0');
  return [fingerprint, language, '$year-$paddedMonth'].join(_keySeparator);
}

/// 나의 사주 캐시 키. 세운 표가 해마다 바뀌므로 연도 단위입니다.
String chartKey({
  required String fingerprint,
  required String language,
  required int year,
}) => [fingerprint, language, '$year'].join(_keySeparator);

/// 오늘 캐시 키. [date]는 `YYYY-MM-DD`입니다.
String dailyKey({
  required String fingerprint,
  required String language,
  required String date,
}) => [fingerprint, language, date].join(_keySeparator);

/// 규칙 버전 기준값을 두는 [DeviceFlags] 키. 규칙 버전은 계정과 무관합니다.
const rulesetVersionFlagKey = 'cache.rulesetVersion';

/// 사주 기반 캐시와 계정별 로컬 데이터. 모든 읽기·쓰기는 [accountId]로 한정됩니다.
final class CacheStore {
  /// [accountId] 범위의 저장소를 만듭니다.
  const new(this._database, {required this.accountId});

  final AppDatabase _database;

  /// 이 저장소가 다루는 계정.
  final String accountId;

  /// 캐시된 JSON을 읽습니다. 없으면 null입니다.
  Future<String?> read(CacheKind kind, String key) async {
    final row =
        await (_database.select(_database.cachedResponses)..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.kind.equals(kind.name) &
                  t.cacheKey.equals(key),
            ))
            .getSingleOrNull();
    return row?.json;
  }

  /// 응답을 씁니다. 같은 키면 덮어씁니다.
  Future<void> write(
    CacheKind kind,
    String key,
    String json, {
    required EvidenceAccess access,
    String? rulesetVersion,
  }) => _database
      .into(_database.cachedResponses)
      .insertOnConflictUpdate(
        CachedResponsesCompanion.insert(
          accountId: accountId,
          kind: kind.name,
          cacheKey: key,
          json: json,
          rulesetVersion: Value(rulesetVersion),
          evidenceAccess: access.value,
          fetchedAt: DateTime.now().toUtc(),
        ),
      );

  /// 사주가 바뀌었을 때 [fingerprint]로 만든 이 계정의 캐시를 모두 지웁니다.
  Future<void> dropFingerprint(String fingerprint) {
    // 지문은 hex라 LIKE 와일드카드를 포함하지 않습니다.
    final prefix = '$fingerprint$_keySeparator';
    return (_database.delete(_database.cachedResponses)..where(
          (t) => t.accountId.equals(accountId) & t.cacheKey.like('$prefix%'),
        ))
        .go();
  }

  /// 새 응답을 쓰기 전에 먼저 관찰해야 합니다. 쓰고 나서 관찰하면 방금 쓴 응답이
  /// 옛 규칙의 캐시로 함께 지워집니다.
  ///
  /// 규칙 버전이 저장된 값과 다르면 사주 기반 캐시(달력·나의 사주)를 모두 지우고
  /// true를 돌려줍니다. 규칙은 계정과 무관하므로 모든 계정의 캐시를 지웁니다.
  /// 처음 부르면 값만 저장하고 false입니다.
  Future<bool> observeRulesetVersion(String version) {
    return _database.transaction(() async {
      final flags = _database.deviceFlags;
      final stored = await (_database.select(
        flags,
      )..where((t) => t.key.equals(rulesetVersionFlagKey))).getSingleOrNull();
      if (stored?.value == version) {
        return false;
      }
      await _database
          .into(flags)
          .insertOnConflictUpdate(
            DeviceFlagsCompanion.insert(
              key: rulesetVersionFlagKey,
              value: version,
            ),
          );
      if (stored == null) {
        return false;
      }
      await (_database.delete(_database.cachedResponses)..where(
            (t) => t.kind.isIn([CacheKind.calendar.name, CacheKind.chart.name]),
          ))
          .go();
      return true;
    });
  }

  /// `locked`로 받아 잠금이 풀리면 다시 받아야 하는 이 계정의 키.
  Future<List<String>> lockedKeys(CacheKind kind) async {
    final rows =
        await (_database.select(_database.cachedResponses)..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.kind.equals(kind.name) &
                  t.evidenceAccess.equals(EvidenceAccess.locked.value),
            ))
            .get();
    return [for (final row in rows) row.cacheKey];
  }

  /// 이 계정의 캐시와 일기 초안을 지웁니다. 온보딩 입력과 기기 플래그는 남깁니다.
  ///
  /// 로그아웃 정리는 계정 id를 모를 때도 돌아야 하므로 이 메서드가 아니라
  /// `AppDatabase.clearSignedOutData`를 씁니다.
  Future<void> clearAccount() {
    return _database.transaction(() async {
      await (_database.delete(
        _database.cachedResponses,
      )..where((t) => t.accountId.equals(accountId))).go();
      await (_database.delete(
        _database.diaryDrafts,
      )..where((t) => t.accountId.equals(accountId))).go();
    });
  }
}

/// 현재 로그인한 계정 id. 인증 흐름이 override합니다.
final currentAccountIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('currentAccountIdProvider를 override하세요.'),
);

/// 현재 계정으로 범위를 정한 캐시 저장소.
final cacheStoreProvider = Provider<CacheStore>(
  (ref) => CacheStore(
    ref.watch(appDatabaseProvider),
    accountId: ref.watch(currentAccountIdProvider),
  ),
);
