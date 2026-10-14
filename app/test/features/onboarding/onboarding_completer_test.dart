import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_finish.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

import '../../support/app_harness.dart';

final _draft = OnboardingDraft(
  honorific: '별님',
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 15),
  time: BirthTime(status: BirthTimeStatusEnum.known, value: '14:30'),
  gender: BirthGenderEnum.female,
);

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Map<String, Object?> _bodyOf(Object? data) =>
    (data is String ? jsonDecode(data) : data)! as Map<String, Object?>;

final _tokens = TokenPair(
  accessToken: 'test-access-token',
  accessTokenExpiresAt: DateTime.utc(2026, 10, 13, 1),
  refreshToken: 'test-refresh-token',
  refreshTokenExpiresAt: DateTime.utc(2026, 11, 12),
);

/// 로그인한 한국 기기에 완전한 온보딩 입력을 둔 [scenario] 컨테이너를 만듭니다.
Future<ProviderContainer> _signedInWithDraft(
  WidgetTester tester,
  String scenario,
) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(scenario, locale: const Locale('ko', 'KR')),
  ))!;
  addTearDown(container.dispose);
  await tester.runAsync(() async {
    await container.read(entryStateProvider.future);
    if (container.read(meProvider) == null) {
      // 로그아웃으로 시작하는 시나리오는 로그인한 상태(약관 동의 전)로 만듭니다.
      await container.read(tokenStoreProvider).save(_tokens);
      await container.read(entryStateProvider.notifier).refresh();
    }
    await container
        .read(onboardingDraftProvider.notifier)
        .update((_) => _draft);
  });
  return container;
}

void main() {
  testWidgets('완전한 입력이면 프로필을 만들고 입력을 지운 뒤 알림 허락 대기를 켜고 진입을 다시 계산합니다', (
    tester,
  ) async {
    final container = await _signedInWithDraft(tester, 'profile-required');
    expect(container.read(entryProvider), EntryState.profileRequired);
    final completer = container.read(onboardingCompleterProvider);
    expect(await tester.runAsync(completer.isReady), isTrue);

    await tester.runAsync(completer.complete);

    final fake = _fake(container);
    expect(_bodyOf(fake.requestBodiesOf('createProfile').single), {
      'honorific': '별님',
      'language': 'ko',
      'currentTimezone': 'Asia/Seoul',
      'birth': {
        'calendar': 'solar',
        'date': {'year': 1990, 'month': 5, 'day': 15},
        'isLeapMonth': false,
        'time': {'status': 'known', 'value': '14:30'},
        'gender': 'female',
        'timezone': 'Asia/Seoul',
        'place': {'status': 'not_asked'},
      },
      'notification': {'status': 'not_asked'},
    });
    // 입력은 메모리와 DB 모두 비었습니다.
    expect(
      container.read(onboardingDraftProvider).value,
      const OnboardingDraft(),
    );
    expect(
      await tester.runAsync(
        () => container.read(onboardingDraftStoreProvider).read(),
      ),
      isNull,
    );
    expect(
      await tester.runAsync(
        () => container
            .read(deviceFlagsStoreProvider)
            .readBool(notifyAskPendingKey),
      ),
      isTrue,
    );
    final cached = await tester.runAsync(
      () => container.read(profileRepositoryProvider).cached(),
    );
    expect(cached?.currentTimezone, 'Asia/Seoul');
    // 프로필을 만든 뒤 다시 계산해 알림 허락 대기로 갑니다.
    expect(fake.callCountOf('getMe'), 2);
    expect(container.read(entryProvider), EntryState.notifyAskRequired);
  });

  testWidgets('onboardingFinishProvider는 completer.complete입니다', (
    tester,
  ) async {
    final container = await _signedInWithDraft(tester, 'profile-required');
    await tester.runAsync(() => container.read(onboardingFinishProvider)());
    expect(_fake(container).callCountOf('createProfile'), 1);
    expect(container.read(entryProvider), EntryState.notifyAskRequired);
  });

  testWidgets('profile-invalid 시나리오: 422면 초안이 남고 OnboardingInputRejected입니다', (
    tester,
  ) async {
    final container = await _signedInWithDraft(tester, 'profile-invalid');
    // 이 시나리오는 로그인 뒤 첫 내 정보가 약관 동의 전이라 진입이 consentRequired입니다.
    // completer는 진입 상태를 보지 않으므로 저장 실패 동작만 확인합니다.
    expect(container.read(entryProvider), EntryState.consentRequired);
    final completer = container.read(onboardingCompleterProvider);
    final getMeBefore = _fake(container).callCountOf('getMe');

    Object? thrown;
    await tester.runAsync(() async {
      try {
        await completer.complete();
      } on Object catch (e) {
        thrown = e;
      }
    });

    expect(thrown, isA<OnboardingInputRejected>());
    final error = (thrown! as OnboardingInputRejected).error;
    expect((error as ProblemError).code, 'birth.invalid');
    expect(container.read(onboardingDraftProvider).value, _draft);
    expect(
      await tester.runAsync(
        () => container.read(onboardingDraftStoreProvider).read(),
      ),
      _draft,
    );
    expect(
      await tester.runAsync(
        () => container
            .read(deviceFlagsStoreProvider)
            .readBool(notifyAskPendingKey),
      ),
      isFalse,
    );
    expect(_fake(container).callCountOf('createProfile'), 1);
    // 저장하지 못했으므로 진입은 다시 계산하지 않습니다.
    expect(_fake(container).callCountOf('getMe'), getMeBefore);
  });

  test('입력 오류 판정: birth.*·date.*·name.*·request.inconsistent의 422만', () {
    ProblemError problem(String code, [int status = 422]) => ProblemError(
      code: code,
      status: status,
      fieldErrors: const [],
      traceId: '',
    );
    expect(isOnboardingInputProblem(problem('birth.invalid')), isTrue);
    expect(isOnboardingInputProblem(problem('birth.out_of_range')), isTrue);
    expect(isOnboardingInputProblem(problem('date.invalid')), isTrue);
    expect(isOnboardingInputProblem(problem('name.too_long')), isTrue);
    expect(isOnboardingInputProblem(problem('request.inconsistent')), isTrue);
    expect(isOnboardingInputProblem(problem('consent.required', 403)), isFalse);
    expect(isOnboardingInputProblem(problem('birth.invalid', 400)), isFalse);
    expect(isOnboardingInputProblem(const OfflineError()), isFalse);
  });

  test('onboardingErrorOf: 입력 오류는 원래 AppError, 그 밖은 UnexpectedError', () {
    const offline = OfflineError();
    expect(onboardingErrorOf(offline), same(offline));
    expect(
      onboardingErrorOf(const OnboardingInputRejected(offline)),
      same(offline),
    );
    expect(onboardingErrorOf(StateError('x')), isA<UnexpectedError>());
  });

  testWidgets('저장 뒤 입력 삭제 전에 중단돼도 알림 허락 대기가 켜져 있어 다음 진입이 notify-ask입니다', (
    tester,
  ) async {
    final container = await _signedInWithDraft(tester, 'profile-required');
    // 입력 삭제가 끝나지 않는(앱이 그 사이 꺼진) completer.
    final completer = OnboardingCompleter(
      profiles: container.read(profileRepositoryProvider),
      readDraft: () => container.read(onboardingDraftProvider.future),
      clearDraft: () => Completer<void>().future,
      language: Language.ko,
      deviceRegionIsKorea: true,
      deviceTimezone: () async => 'Asia/Seoul',
      flags: container.read(deviceFlagsStoreProvider),
      refreshEntry: () => container.read(entryStateProvider.notifier).refresh(),
      crashReporter: FakeCrashReporter(),
    );
    await tester.runAsync(() async {
      unawaited(completer.complete());
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    expect(_fake(container).callCountOf('createProfile'), 1);
    expect(
      await tester.runAsync(
        () => container
            .read(deviceFlagsStoreProvider)
            .readBool(notifyAskPendingKey),
      ),
      isTrue,
    );
    // 다시 열린 앱의 진입 계산.
    await tester.runAsync(
      () => container.read(entryStateProvider.notifier).refresh(),
    );
    expect(container.read(entryProvider), EntryState.notifyAskRequired);
  });
}
