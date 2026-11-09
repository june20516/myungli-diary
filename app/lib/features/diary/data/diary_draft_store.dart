import 'package:drift/drift.dart';
import 'package:myungli_diary/core/api/gen/model/guide_choice.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/diary/model/diary_draft_target.dart';

/// 일기 초안 저장소(`DiaryDrafts`). (날짜, 일기 id)당 1개이고 모든 읽기·쓰기는 [accountId]로
/// 한정됩니다(D47②: 오프라인은 로컬 초안만, A48).
///
/// 로그아웃하면 정리(`SignOutCleaner`)가 모든 계정의 초안을 지웁니다.
final class DiaryDraftStore {
  /// [accountId] 범위의 초안 저장소를 만듭니다. `nowUtc`는 마지막 저장 시각입니다.
  const new(this._database, {required this.accountId, required this._nowUtc});

  final AppDatabase _database;
  final DateTime Function() _nowUtc;

  /// 소유 계정 id.
  final String accountId;

  /// [target] 초안(본문과 고른 질문). 없으면 null입니다.
  Future<DiaryDraft?> find(DiaryDraftTarget target) => (_database.select(
    _database.diaryDrafts,
  )..where((t) => _matches(t, target))).getSingleOrNull();

  /// [target] 초안 본문. 없으면 null입니다.
  Future<String?> read(DiaryDraftTarget target) async =>
      (await find(target))?.body;

  /// [target] 초안을 [body]와 고른 질문 [guide]로 씁니다(있으면 바꿈). [guide]가 없으면 고른
  /// 질문을 비웁니다(A115).
  Future<void> write(
    DiaryDraftTarget target,
    String body, {
    GuideChoice? guide,
  }) => _database
      .into(_database.diaryDrafts)
      .insertOnConflictUpdate(
        DiaryDraftsCompanion.insert(
          accountId: accountId,
          date: target.date.toIso(),
          diaryId: Value(target.diaryId),
          body: body,
          guideMessageKey: Value(guide?.messageKey),
          guideVariant: Value(guide?.variant),
          updatedAt: _nowUtc(),
        ),
      );

  /// [target] 초안만 지웁니다.
  Future<void> remove(DiaryDraftTarget target) => (_database.delete(
    _database.diaryDrafts,
  )..where((t) => _matches(t, target))).go();

  Expression<bool> _matches($DiaryDraftsTable t, DiaryDraftTarget target) =>
      t.accountId.equals(accountId) &
      t.date.equals(target.date.toIso()) &
      t.diaryId.equals(target.diaryId);
}
