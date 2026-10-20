import 'package:drift/drift.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

/// 일기 초안 저장소(`DiaryDrafts`). 날짜당 1개이고 모든 읽기·쓰기는 [accountId]로
/// 한정됩니다(D47②: 오프라인은 로컬 초안만, A48).
///
/// 로그아웃하면 정리(`SignOutCleaner`)가 모든 계정의 초안을 지웁니다.
final class DiaryDraftStore {
  /// [accountId] 범위의 초안 저장소를 만듭니다. [nowUtc]는 마지막 저장 시각입니다.
  const new(this._database, {required this.accountId, required this._nowUtc});

  final AppDatabase _database;
  final DateTime Function() _nowUtc;

  /// 소유 계정 id.
  final String accountId;

  /// [date] 초안 본문. 없으면 null입니다.
  Future<String?> read(CalendarDate date) async {
    final row =
        await (_database.select(_database.diaryDrafts)..where(
              (t) =>
                  t.accountId.equals(accountId) & t.date.equals(date.toIso()),
            ))
            .getSingleOrNull();
    return row?.body;
  }

  /// [date] 초안을 [body]로 씁니다(있으면 바꿈).
  Future<void> write(CalendarDate date, String body) => _database
      .into(_database.diaryDrafts)
      .insertOnConflictUpdate(
        DiaryDraftsCompanion.insert(
          accountId: accountId,
          date: date.toIso(),
          body: body,
          updatedAt: _nowUtc(),
        ),
      );

  /// [date] 초안을 지웁니다.
  Future<void> remove(CalendarDate date) =>
      (_database.delete(_database.diaryDrafts)..where(
            (t) => t.accountId.equals(accountId) & t.date.equals(date.toIso()),
          ))
          .go();
}
