import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';

void main() {
  late AppDatabase database;
  late CacheStore store;

  setUp(() {
    database = AppDatabase.forExecutor(NativeDatabase.memory());
    store = CacheStore(database, accountId: 'a');
  });

  tearDown(() => database.close());

  Future<void> writeCalendar(
    CacheStore target,
    String fingerprint, {
    EvidenceAccess access = EvidenceAccess.unlocked,
    int month = 10,
  }) => target.write(
    CacheKind.calendar,
    calendarKey(
      fingerprint: fingerprint,
      language: 'ko',
      year: 2026,
      month: month,
    ),
    '{"fp":"$fingerprint"}',
    access: access,
  );

  String calendar(String fingerprint, {int month = 10}) => calendarKey(
    fingerprint: fingerprint,
    language: 'ko',
    year: 2026,
    month: month,
  );

  test('쓴 값을 읽고, 같은 키에 쓰면 덮어쓴다', () async {
    await writeCalendar(store, 'A');
    await store.write(
      CacheKind.calendar,
      calendar('A'),
      '{"v":2}',
      access: EvidenceAccess.unlocked,
    );

    expect(await store.read(CacheKind.calendar, calendar('A')), '{"v":2}');
    expect(await store.read(CacheKind.chart, calendar('A')), isNull);
  });

  test('키는 월을 두 자리로 맞추고 연도 단위·날짜 단위를 구분한다', () {
    expect(calendar('A', month: 3), 'A|ko|2026-03');
    expect(chartKey(fingerprint: 'A', language: 'ko', year: 2026), 'A|ko|2026');
    expect(
      dailyKey(fingerprint: 'A', language: 'ko', date: '2026-10-13'),
      'A|ko|2026-10-13',
    );
  });

  test('dropFingerprint는 해당 사주의 모든 종류를 지우고 다른 사주는 남긴다', () async {
    await writeCalendar(store, 'A');
    await writeCalendar(store, 'B');
    await store.write(
      CacheKind.daily,
      dailyKey(fingerprint: 'A', language: 'ko', date: '2026-10-13'),
      '{}',
      access: EvidenceAccess.unlocked,
    );

    await store.dropFingerprint('A');

    expect(await store.read(CacheKind.calendar, calendar('A')), isNull);
    expect(
      await store.read(
        CacheKind.daily,
        dailyKey(fingerprint: 'A', language: 'ko', date: '2026-10-13'),
      ),
      isNull,
    );
    expect(await store.read(CacheKind.calendar, calendar('B')), isNotNull);
  });

  test('dropFingerprint는 다른 계정의 같은 지문은 지우지 않는다', () async {
    final other = CacheStore(database, accountId: 'b');
    await writeCalendar(store, 'A');
    await writeCalendar(other, 'A');

    await store.dropFingerprint('A');

    expect(await store.read(CacheKind.calendar, calendar('A')), isNull);
    expect(await other.read(CacheKind.calendar, calendar('A')), isNotNull);
  });

  group('observeRulesetVersion', () {
    test('처음은 false, 같은 값도 false, 다른 값은 true', () async {
      expect(await store.observeRulesetVersion('2026.10.1'), isFalse);
      expect(await store.observeRulesetVersion('2026.10.1'), isFalse);
      expect(await store.observeRulesetVersion('2026.11.0'), isTrue);
      expect(await store.observeRulesetVersion('2026.11.0'), isFalse);
    });

    test('바뀌면 calendar·chart가 비고 daily·glossary는 남는다', () async {
      await store.observeRulesetVersion('2026.10.1');
      await writeCalendar(store, 'A');
      await store.write(
        CacheKind.chart,
        chartKey(fingerprint: 'A', language: 'ko', year: 2026),
        '{}',
        access: EvidenceAccess.unlocked,
      );
      await store.write(
        CacheKind.daily,
        dailyKey(fingerprint: 'A', language: 'ko', date: '2026-10-13'),
        '{}',
        access: EvidenceAccess.unlocked,
      );
      await store.write(
        CacheKind.glossary,
        'ko',
        '{}',
        access: EvidenceAccess.unlocked,
      );

      expect(await store.observeRulesetVersion('2026.11.0'), isTrue);

      expect(await store.read(CacheKind.calendar, calendar('A')), isNull);
      expect(
        await store.read(
          CacheKind.chart,
          chartKey(fingerprint: 'A', language: 'ko', year: 2026),
        ),
        isNull,
      );
      expect(
        await store.read(
          CacheKind.daily,
          dailyKey(fingerprint: 'A', language: 'ko', date: '2026-10-13'),
        ),
        isNotNull,
      );
      expect(await store.read(CacheKind.glossary, 'ko'), isNotNull);
    });

    test('기준값은 계정과 무관해 다른 계정의 저장소에도 적용된다', () async {
      final other = CacheStore(database, accountId: 'b');
      await store.observeRulesetVersion('2026.10.1');
      await writeCalendar(other, 'A');

      expect(await other.observeRulesetVersion('2026.11.0'), isTrue);
      expect(await other.read(CacheKind.calendar, calendar('A')), isNull);
    });
  });

  test('locked로 쓴 키만 lockedKeys에 나온다', () async {
    await writeCalendar(store, 'A', access: EvidenceAccess.locked);
    await writeCalendar(store, 'A', month: 11);
    await store.write(
      CacheKind.chart,
      'chart-locked',
      '{}',
      access: EvidenceAccess.locked,
    );

    expect(await store.lockedKeys(CacheKind.calendar), [calendar('A')]);
    expect(await store.lockedKeys(CacheKind.chart), ['chart-locked']);
    expect(await store.lockedKeys(CacheKind.daily), isEmpty);
  });

  test('잠금이 풀린 값으로 다시 쓰면 lockedKeys에서 빠진다', () async {
    await writeCalendar(store, 'A', access: EvidenceAccess.locked);
    await writeCalendar(store, 'A');

    expect(await store.lockedKeys(CacheKind.calendar), isEmpty);
  });

  group('계정 범위', () {
    test('계정 a가 쓴 캐시는 계정 b에서 읽히지 않고 lockedKeys에도 없다', () async {
      final other = CacheStore(database, accountId: 'b');
      await writeCalendar(store, 'A', access: EvidenceAccess.locked);

      expect(await other.read(CacheKind.calendar, calendar('A')), isNull);
      expect(await other.lockedKeys(CacheKind.calendar), isEmpty);
    });

    Future<void> seed() async {
      for (final account in ['a', 'b']) {
        await CacheStore(
          database,
          accountId: account,
        ).write(CacheKind.daily, 'k', '{}', access: EvidenceAccess.unlocked);
        await database
            .into(database.diaryDrafts)
            .insert(
              DiaryDraftsCompanion.insert(
                accountId: account,
                date: '2026-10-13',
                body: '초안 $account',
                updatedAt: DateTime.utc(2026, 10, 13),
              ),
            );
      }
      await database
          .into(database.onboardingInputs)
          .insert(
            OnboardingInputsCompanion.insert(
              json: '{"honorific":"하늘"}',
              updatedAt: DateTime.utc(2026, 10, 13),
            ),
          );
      await database
          .into(database.deviceFlags)
          .insert(DeviceFlagsCompanion.insert(key: 'ads.consent', value: '1'));
    }

    Future<int> count(
      ResultSetImplementation<HasResultSet, Object?> table,
    ) async => (await database.select(table).get()).length;

    test('clearAccount는 그 계정의 캐시·초안만 지우고 나머지는 남긴다', () async {
      await seed();

      await store.clearAccount();

      final other = CacheStore(database, accountId: 'b');
      expect(await store.read(CacheKind.daily, 'k'), isNull);
      expect(await other.read(CacheKind.daily, 'k'), isNotNull);
      final drafts = await database.select(database.diaryDrafts).get();
      expect(drafts.map((d) => d.accountId), ['b']);
      expect(await count(database.onboardingInputs), 1);
      expect(await count(database.deviceFlags), 1);
    });

    test('clearOnSignOut은 캐시·초안·온보딩 입력을 지우고 기기 플래그는 남긴다', () async {
      await seed();

      await store.clearOnSignOut();

      expect(await store.read(CacheKind.daily, 'k'), isNull);
      final drafts = await database.select(database.diaryDrafts).get();
      expect(drafts.map((d) => d.accountId), ['b']);
      expect(await count(database.onboardingInputs), 0);
      expect(await count(database.deviceFlags), 1);
    });

    test('clearOnboardingInputs는 온보딩 입력만 지운다', () async {
      await seed();

      await store.clearOnboardingInputs();

      expect(await count(database.onboardingInputs), 0);
      expect(await count(database.diaryDrafts), 2);
      expect(await count(database.cachedResponses), 2);
    });
  });
}
