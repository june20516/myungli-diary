import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/guide_choice.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/diary/data/diary_draft_store.dart';
import 'package:myungli_diary/features/diary/model/diary_draft_target.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forExecutor(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  final day = CalendarDate(2026, 10, 13);
  final target = DiaryDraftTarget.newOn(day);

  test('쓴 초안을 같은 계정·대상으로 읽고, 다시 쓰면 바뀝니다', () async {
    final store = DiaryDraftStore(
      database,
      accountId: 'a',
      nowUtc: () => DateTime.utc(2026, 10, 13),
    );
    expect(await store.read(target), isNull);
    await store.write(target, '첫 글');
    await store.write(target, '고친 글');
    expect(await store.read(target), '고친 글');
    expect(
      await store.read(DiaryDraftTarget.newOn(CalendarDate(2026, 10, 12))),
      isNull,
    );
  });

  test('다른 계정의 초안은 보이지 않습니다', () async {
    final a = DiaryDraftStore(database, accountId: 'a', nowUtc: DateTime.now);
    final b = DiaryDraftStore(database, accountId: 'b', nowUtc: DateTime.now);
    await a.write(target, 'a의 글');
    expect(await b.read(target), isNull);
  });

  test('같은 날 새 일기 초안과 고치는 일기 초안은 따로 남는다', () async {
    final store = DiaryDraftStore(
      database,
      accountId: 'a',
      nowUtc: DateTime.now,
    );
    await store.write(DiaryDraftTarget.newOn(day), 'A');
    await store.write(DiaryDraftTarget.existing(date: day, id: 'x'), 'B');
    expect(await store.read(DiaryDraftTarget.newOn(day)), 'A');
    expect(
      await store.read(DiaryDraftTarget.existing(date: day, id: 'x')),
      'B',
    );
    expect(
      await store.read(DiaryDraftTarget.existing(date: day, id: 'y')),
      isNull,
    );
  });

  test('remove는 그 대상만 지운다', () async {
    final store = DiaryDraftStore(
      database,
      accountId: 'a',
      nowUtc: DateTime.now,
    );
    final existing = DiaryDraftTarget.existing(date: day, id: 'x');
    await store.write(target, 'A');
    await store.write(existing, 'B');
    await store.remove(target);
    expect(await store.read(target), isNull);
    expect(await store.read(existing), 'B');
  });

  test('DiaryDraftTarget은 값 동등성을 가진다', () {
    final x = DiaryDraftTarget.existing(date: day, id: 'x');
    expect(x == DiaryDraftTarget.existing(date: day, id: 'x'), isTrue);
    expect(x.hashCode, DiaryDraftTarget.existing(date: day, id: 'x').hashCode);
    expect(x == DiaryDraftTarget.existing(date: day, id: 'y'), isFalse);
    expect(DiaryDraftTarget.newOn(day) == DiaryDraftTarget.newOn(day), isTrue);
    expect(DiaryDraftTarget.newOn(day) == x, isFalse);
    expect(DiaryDraftTarget.newOn(day).diaryId, '');
  });

  test('고치는 일기 id는 비어 있을 수 없다', () {
    expect(
      () => DiaryDraftTarget.existing(date: day, id: ''),
      throwsA(isA<AssertionError>()),
    );
  });

  test('고른 질문(messageKey, variant)을 본문과 함께 남기고 읽습니다(A115)', () async {
    final store = DiaryDraftStore(
      database,
      accountId: 'a',
      nowUtc: () => DateTime.utc(2026, 10, 13),
    );
    await store.write(
      target,
      '글',
      guide: GuideChoice(messageKey: 'guide.dohwa', variant: '2'),
    );
    final draft = await store.find(target);
    expect(draft!.body, '글');
    expect(draft.guideMessageKey, 'guide.dohwa');
    expect(draft.guideVariant, '2');

    // 고르지 않은 채 다시 쓰면 고른 질문도 비웁니다.
    await store.write(target, '고친 글');
    final rewritten = await store.find(target);
    expect(rewritten!.body, '고친 글');
    expect(rewritten.guideMessageKey, isNull);
    expect(rewritten.guideVariant, isNull);
    expect(await store.read(target), '고친 글');
  });
}
