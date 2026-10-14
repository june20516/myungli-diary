import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';

/// 온보딩 입력을 로컬 DB 단일 행(`OnboardingInputs`, id=1)에 두는 저장소입니다.
///
/// 로그인 전에 쓰므로 계정과 무관합니다. 로그아웃 정리가 지웁니다.
final class OnboardingDraftStore {
  /// `database`에 저장합니다.
  new(this._database);

  final AppDatabase _database;

  /// 저장한 입력을 읽습니다. 없거나 형식이 다르거나 깨졌으면 null입니다(처음부터 입력).
  Future<OnboardingDraft?> read() async {
    final row = await _database
        .select(_database.onboardingInputs)
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(row.json);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return OnboardingDraft.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  /// [draft]를 저장합니다. 이미 있으면 덮어씁니다.
  Future<void> write(OnboardingDraft draft) => _database
      .into(_database.onboardingInputs)
      .insertOnConflictUpdate(
        OnboardingInputsCompanion(
          id: const Value(1),
          json: Value(jsonEncode(draft.toJson())),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// 저장한 입력을 지웁니다.
  Future<void> clear() => _database.delete(_database.onboardingInputs).go();
}

/// 온보딩 입력 저장소.
final onboardingDraftStoreProvider = Provider<OnboardingDraftStore>(
  (ref) => OnboardingDraftStore(ref.watch(appDatabaseProvider)),
);
