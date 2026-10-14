import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';

final _draft = OnboardingDraft(
  honorific: '하늘',
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 17),
  time: BirthTime(status: BirthTimeStatusEnum.unknown),
  gender: BirthGenderEnum.male,
);

void main() {
  late AppDatabase database;
  late OnboardingDraftStore store;

  setUp(() {
    database = AppDatabase.forExecutor(NativeDatabase.memory());
    store = OnboardingDraftStore(database);
  });
  tearDown(() => database.close());

  test('저장한 적 없으면 null이다', () async {
    expect(await store.read(), isNull);
  });

  test('write 뒤 read가 같다', () async {
    await store.write(_draft);
    expect(await store.read(), _draft);
  });

  test('두 번 써도 행은 하나이고 마지막 값이다', () async {
    await store.write(_draft);
    final next = _draft.copyWith(honorific: '바다');
    await store.write(next);
    expect(
      await database.select(database.onboardingInputs).get(),
      hasLength(1),
    );
    expect(await store.read(), next);
  });

  test('clear 뒤 null이다', () async {
    await store.write(_draft);
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('로그아웃 정리 뒤 null이다', () async {
    await store.write(_draft);
    await database.clearSignedOutData();
    expect(await store.read(), isNull);
  });

  test('깨진 JSON이나 다른 형식 버전이면 null이다', () async {
    for (final broken in [
      'not json',
      '[]',
      '{"v":2}',
      '{"v":1,"gender":"x"}',
    ]) {
      await database
          .into(database.onboardingInputs)
          .insertOnConflictUpdate(
            OnboardingInputsCompanion(
              id: const Value(1),
              json: Value(broken),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      expect(await store.read(), isNull, reason: broken);
    }
  });

  group('onboardingDraftProvider', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
    });
    tearDown(() => container.dispose());

    test('저장한 값이 없으면 빈 입력으로 시작한다', () async {
      expect(
        await container.read(onboardingDraftProvider.future),
        const OnboardingDraft(),
      );
    });

    test('update는 상태를 바꾸고 바로 저장한다', () async {
      await container
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(honorific: '하늘'));
      expect(container.read(onboardingDraftProvider).value?.honorific, '하늘');
      expect((await store.read())?.honorific, '하늘');
    });

    test('저장한 값이 있으면 이어서 시작한다', () async {
      await store.write(_draft);
      expect(await container.read(onboardingDraftProvider.future), _draft);
    });

    test('clear는 저장과 상태를 지운다', () async {
      await store.write(_draft);
      await container.read(onboardingDraftProvider.future);
      await container.read(onboardingDraftProvider.notifier).clear();
      expect(await store.read(), isNull);
      expect(
        container.read(onboardingDraftProvider).value,
        const OnboardingDraft(),
      );
    });
  });
}
