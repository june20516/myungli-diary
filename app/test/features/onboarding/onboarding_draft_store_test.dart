import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';

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
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
        ],
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

    test('앞선 쓰기가 늦어져도 DB 값은 마지막 상태다', () async {
      final slow = _GatedStore(database, gatedWrites: 1);
      final gated = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
          onboardingDraftStoreProvider.overrideWithValue(slow),
        ],
      );
      addTearDown(gated.dispose);
      final notifier = gated.read(onboardingDraftProvider.notifier);
      await gated.read(onboardingDraftProvider.future);
      final first = notifier.update((d) => d.copyWith(honorific: '하나'));
      final second = notifier.update((d) => d.copyWith(honorific: '둘'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      slow.release();
      await Future.wait([first, second]);
      expect((await store.read())?.honorific, '둘');
    });

    ProviderContainer gatedContainer(
      _GatedStore gated, {
      FakeCrashReporter? reporter,
    }) {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
          onboardingDraftStoreProvider.overrideWithValue(gated),
          if (reporter != null)
            crashReporterProvider.overrideWithValue(reporter),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('큐에서 기다리던 쓰기는 로그아웃 뒤 건너뛴다', () async {
      final slow = _GatedStore(database, gatedWrites: 1);
      final gated = gatedContainer(slow);
      final notifier = gated.read(onboardingDraftProvider.notifier);
      await gated.read(onboardingDraftProvider.future);
      final first = notifier.update((d) => d.copyWith(honorific: '하나'));
      final second = notifier.update((d) => d.copyWith(honorific: '둘'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await gated.read(tokenStoreProvider).signOut();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      slow.release();
      await Future.wait([first, second]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(slow.written.map((d) => d.honorific), ['하나']);
      expect(await store.read(), isNull);
      expect(
        gated.read(onboardingDraftProvider).value,
        const OnboardingDraft(),
      );
    });

    test('처음 읽는 중에 로그아웃하면 읽은 이전 행을 올리지 않는다', () async {
      await store.write(_draft);
      final slow = _GatedStore(database, gateRead: true);
      final gated = gatedContainer(slow);
      final loading = gated.read(onboardingDraftProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await gated.read(tokenStoreProvider).signOut();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      slow.release();

      expect(await loading, const OnboardingDraft());
      expect(
        gated.read(onboardingDraftProvider).value,
        const OnboardingDraft(),
      );
    });

    test('정리가 실패해도 미처리 오류 없이 비정상 종료 보고에 요약만 남긴다', () async {
      final failing = _GatedStore(database)..failClear = true;
      final reporter = FakeCrashReporter();
      final gated = gatedContainer(failing, reporter: reporter);
      await gated.read(onboardingDraftProvider.future);

      await gated.read(tokenStoreProvider).signOut();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(reporter.errors.map((e) => e.errorType), ['StateError']);
      expect(
        gated.read(onboardingDraftProvider).value,
        const OnboardingDraft(),
      );
    });

    test('쓰기가 진행되는 중에 로그아웃하면 행이 남지 않고 상태는 비어 있다', () async {
      final slow = _GatedStore(database, gatedWrites: 1);
      final gated = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
          onboardingDraftStoreProvider.overrideWithValue(slow),
        ],
      );
      addTearDown(gated.dispose);
      final notifier = gated.read(onboardingDraftProvider.notifier);
      await gated.read(onboardingDraftProvider.future);
      final pending = notifier.update((d) => _draft);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await gated.read(tokenStoreProvider).signOut();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      slow.release();
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await store.read(), isNull);
      expect(
        gated.read(onboardingDraftProvider).value,
        const OnboardingDraft(),
      );
    });

    test('update 콜백이 도는 중에 로그아웃하면 이전 값으로 되돌아가지 않는다', () async {
      final notifier = container.read(onboardingDraftProvider.notifier);
      await container.read(onboardingDraftProvider.future);
      final gate = Completer<void>();
      final pending = notifier.update((d) async {
        await gate.future;
        return _draft;
      });

      await container.read(tokenStoreProvider).signOut();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await store.read(), isNull);
      expect(
        container.read(onboardingDraftProvider).value,
        const OnboardingDraft(),
      );
    });

    test('로그아웃하면 메모리 입력이 비고 이전 값이 DB에 다시 쓰이지 않는다', () async {
      await store.write(_draft);
      await container.read(onboardingDraftProvider.future);

      await container.read(tokenStoreProvider).signOut();
      await Future<void>.delayed(Duration.zero);
      expect(
        await container.read(onboardingDraftProvider.future),
        const OnboardingDraft(),
      );

      await container
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(honorific: '새'));
      final saved = await store.read();
      expect(saved?.honorific, '새');
      expect(saved?.date, isNull);
      expect(saved?.gender, isNull);
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

/// 앞의 [gatedWrites]번 쓰기와 첫 읽기(옵션)를 [release]까지 붙잡아 두는 저장소 대역입니다.
class _GatedStore extends OnboardingDraftStore {
  // 부모의 비공개 매개변수 이름(_database)을 쓸 수 없어 이름이 다릅니다.
  // ignore: matching_super_parameters
  new(super.database, {this.gatedWrites = 0, this.gateRead = false});

  int gatedWrites;
  final bool gateRead;
  final _gate = Completer<void>();

  /// 실제로 저장한 초안(붙잡힌 쓰기는 풀린 뒤에 기록).
  final written = <OnboardingDraft>[];

  /// true면 `clear`가 실패합니다.
  bool failClear = false;

  void release() => _gate.complete();

  @override
  Future<OnboardingDraft?> read() async {
    final result = await super.read();
    if (gateRead) {
      await _gate.future;
    }
    return result;
  }

  @override
  Future<void> write(OnboardingDraft draft) async {
    if (gatedWrites > 0) {
      gatedWrites--;
      await _gate.future;
    }
    written.add(draft);
    await super.write(draft);
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      throw StateError('clear 실패');
    }
    await super.clear();
  }
}
