import 'package:flutter/material.dart' show Locale, TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/auth/application/consent_controller.dart';
import 'package:myungli_diary/features/onboarding/application/notify_ask_controller.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';

import '../support/app_harness.dart';

/// [failNext]가 켜져 있으면 다음 갱신 한 번을 계산 없이 실패시키는 진입 갈래(오프라인 등).
///
/// 실제로 실패한 갱신처럼 state는 이전 값 그대로 둡니다.
class _FlakyEntry extends EntryController {
  bool failNext = false;

  @override
  Future<AppError?> refresh() async {
    if (failNext) {
      failNext = false;
      return const OfflineError();
    }
    return await super.refresh();
  }
}

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// [scenario] 컨테이너를 만들고 진입 계산이 끝날 때까지 기다립니다.
Future<(ProviderContainer, _FlakyEntry)> _start(
  WidgetTester tester,
  String scenario,
) async {
  final entry = _FlakyEntry();
  final container = (await tester.runAsync(
    () => bootstrapForTest(
      scenario,
      locale: const Locale('ko', 'KR'),
      overrides: [entryStateProvider.overrideWith(() => entry)],
    ),
  ))!;
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(entryStateProvider.future));
  return (container, entry);
}

Future<bool> _notifyAskPending(
  WidgetTester tester,
  ProviderContainer container,
) async => (await tester.runAsync(
  () => container.read(deviceFlagsStoreProvider).readBool(notifyAskPendingKey),
))!;

void main() {
  testWidgets('consent: 동의 뒤 진입 계산이 실패하면 그 오류를 돌려주고 다시 동의하면 진행합니다', (
    tester,
  ) async {
    final (container, entry) = await _start(tester, 'consent-renewal');
    expect(container.read(entryProvider), EntryState.consentRequired);
    final documents = container.read(meProvider)!.requiredConsents;
    final subscription = container.listen(consentControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(consentControllerProvider.notifier);

    entry.failNext = true;
    final failure = await tester.runAsync(() => controller.agree(documents));
    expect(failure, isA<OfflineError>());
    expect(container.read(entryProvider), EntryState.consentRequired);

    final retry = await tester.runAsync(() => controller.agree(documents));
    expect(retry, isNull);
    expect(container.read(entryProvider), isNot(EntryState.consentRequired));
    expect(_fake(container).callCountOf('createProfile'), 0);
  });

  testWidgets('notify-ask: 저장 뒤 진입 계산이 실패하면 그 오류를 돌려주고 다시 누르면 진행합니다', (
    tester,
  ) async {
    final (container, entry) = await _start(tester, 'member');
    final subscription = container.listen(
      notifyAskControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(notifyAskControllerProvider.notifier);

    entry.failNext = true;
    final failure = await tester.runAsync(
      () => controller.allow(const TimeOfDay(hour: 8, minute: 0)),
    );
    expect(failure, isA<OfflineError>());

    final retry = await tester.runAsync(
      () => controller.allow(const TimeOfDay(hour: 8, minute: 0)),
    );
    expect(retry, isNull);
    // 이미 등록한 기기는 다시 등록하지 않습니다.
    expect(_fake(container).callCountOf('registerDevice'), 1);
  });

  testWidgets('completer: 저장 뒤 진입 계산이 실패하면 오류를 던지고, 다시 부르면 저장 없이 갱신만 합니다', (
    tester,
  ) async {
    final (container, entry) = await _start(tester, 'profile-required');
    expect(container.read(entryProvider), EntryState.profileRequired);
    await tester.runAsync(
      () => container
          .read(onboardingDraftProvider.notifier)
          .update(
            (_) => OnboardingDraft(
              honorific: '별님',
              calendar: CalendarType.solar,
              date: LunarOrSolarDate(year: 1990, month: 5, day: 15),
              time: BirthTime(
                status: BirthTimeStatusEnum.known,
                value: '14:30',
              ),
              gender: BirthGenderEnum.female,
            ),
          ),
    );
    final completer = container.read(onboardingCompleterProvider);

    entry.failNext = true;
    Object? thrown;
    await tester.runAsync(() async {
      try {
        await completer.complete();
      } on Object catch (error) {
        thrown = error;
      }
    });
    expect(thrown, isA<OfflineError>());
    expect(_fake(container).callCountOf('createProfile'), 1);
    expect(await _notifyAskPending(tester, container), isTrue);
    // 갈래는 이전 값 그대로라 화면이 넘어가지 않습니다(화면이 오류를 안내).
    expect(container.read(entryProvider), EntryState.profileRequired);

    // 입력은 지워졌지만 이미 저장했으므로 다시 저장하지 않고 진입만 다시 계산합니다.
    await tester.runAsync(completer.complete);
    expect(_fake(container).callCountOf('createProfile'), 1);
    expect(container.read(entryProvider), EntryState.notifyAskRequired);
  });
}
