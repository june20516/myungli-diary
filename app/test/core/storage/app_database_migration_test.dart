import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/diary/data/diary_draft_store.dart';
import 'package:myungli_diary/features/diary/model/diary_draft_target.dart';

void main() {
  test('v1 날짜 초안은 v2 새 일기 초안으로 옮겨진다', () async {
    final day = CalendarDate(2026, 10, 13);
    // v1 표를 raw SQL로 만들어 두고 schemaVersion 2로 엽니다(setup은 마이그레이션 전에 돕니다).
    final database = AppDatabase.forExecutor(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute('''
              CREATE TABLE diary_drafts (
                account_id TEXT NOT NULL,
                date TEXT NOT NULL,
                body TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (account_id, date)
              )''')
            ..execute('INSERT INTO diary_drafts VALUES (?, ?, ?, ?)', [
              'a',
              day.toIso(),
              '옛 초안',
              1760000000,
            ])
            ..execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(database.close);

    final store = DiaryDraftStore(
      database,
      accountId: 'a',
      nowUtc: DateTime.now,
    );
    expect(await store.read(DiaryDraftTarget.newOn(day)), '옛 초안');
    expect(
      await store.read(DiaryDraftTarget.existing(date: day, id: 'x')),
      isNull,
    );
  });
}
