import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/diary/data/diary_draft_store.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forExecutor(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  final day = CalendarDate(2026, 10, 13);

  test('쓴 초안을 같은 계정·날짜로 읽고, 다시 쓰면 바뀝니다', () async {
    final store = DiaryDraftStore(
      database,
      accountId: 'a',
      nowUtc: () => DateTime.utc(2026, 10, 13),
    );
    expect(await store.read(day), isNull);
    await store.write(day, '첫 글');
    await store.write(day, '고친 글');
    expect(await store.read(day), '고친 글');
    expect(await store.read(CalendarDate(2026, 10, 12)), isNull);
  });

  test('다른 계정의 초안은 보이지 않습니다', () async {
    final a = DiaryDraftStore(database, accountId: 'a', nowUtc: DateTime.now);
    final b = DiaryDraftStore(database, accountId: 'b', nowUtc: DateTime.now);
    await a.write(day, 'a의 글');
    expect(await b.read(day), isNull);
  });

  test('remove 뒤에는 없습니다', () async {
    final store = DiaryDraftStore(
      database,
      accountId: 'a',
      nowUtc: DateTime.now,
    );
    await store.write(day, '글');
    await store.remove(day);
    expect(await store.read(day), isNull);
  });
}
