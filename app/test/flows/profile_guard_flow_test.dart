import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Finder _screen(String id) => find.byKey(ValueKey(id));

final Finder _back = find.byKey(const ValueKey('app-bar.back'));

final _completeDraft = OnboardingDraft(
  honorific: '별님',
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 15),
  time: BirthTime(status: BirthTimeStatusEnum.known, value: '14:30'),
  gender: BirthGenderEnum.female,
);

/// 처음 읽을 때 [_seed]를 저장해 두는 저장소(이전 실행에서 남은 입력).
class _SeededDraftStore extends OnboardingDraftStore {
  new(super._database, this._seed);

  OnboardingDraft? _seed;

  @override
  Future<OnboardingDraft?> read() async {
    final seed = _seed;
    if (seed != null) {
      _seed = null;
      await write(seed);
    }
    return await super.read();
  }
}

void main() {
  group('프로필이 있는 계정은 온보딩 입력으로 프로필을 다시 만들지 않습니다', () {
    testWidgets('ready 회원이 수정 모드 없이 온보딩 단계로 오면 today', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'member',
        locale: koreaLocale,
      );
      expect(_screen(ScreenIds.today), findsOneWidget);
      final router = container.read(routerProvider);

      for (final id in [ScreenIds.onboardGender, ScreenIds.onboardCall]) {
        router.go(pathOf(id));
        await tester.pumpAndSettle();
        expect(_screen(ScreenIds.today), findsOneWidget, reason: id);
        expect(_screen(id), findsNothing, reason: id);
      }
      expect(_fake(container).callCountOf('createProfile'), 0);

      // 수정 모드(A19)는 그대로 열립니다.
      router.go('${pathOf(ScreenIds.onboardGender)}?mode=edit');
      await tester.pumpAndSettle();
      expect(_screen(ScreenIds.onboardGender), findsOneWidget);
    });

    testWidgets(
      'completer는 프로필이 있는 계정에서 StateError이고 createProfile을 부르지 않습니다',
      (tester) async {
        final container = await pumpApp(
          tester,
          scenario: 'member',
          locale: koreaLocale,
        );
        // 완전한 입력이 남아 있어도(정리 전) 저장하지 않아야 합니다.
        await tester.runAsync(
          () => container
              .read(onboardingDraftProvider.notifier)
              .update((_) => _completeDraft),
        );
        final completer = container.read(onboardingCompleterProvider);

        Object? thrown;
        await tester.runAsync(() async {
          try {
            await completer.complete();
          } on Object catch (error) {
            thrown = error;
          }
        });

        expect(thrown, isA<StateError>());
        expect(_fake(container).callCountOf('createProfile'), 0);
      },
    );

    testWidgets('프로필 있는 갈래로 진입하면 남은 온보딩 입력을 지웁니다', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'member',
        locale: koreaLocale,
        overrides: [
          onboardingDraftStoreProvider.overrideWith(
            (ref) => _SeededDraftStore(
              ref.watch(appDatabaseProvider),
              _completeDraft,
            ),
          ),
        ],
      );
      await pumpUntil(
        tester,
        () =>
            container.read(onboardingDraftProvider).value ==
            const OnboardingDraft(),
      );
      expect(
        await tester.runAsync(
          () => container.read(onboardingDraftStoreProvider).read(),
        ),
        isNull,
      );
    });

    testWidgets('프로필이 없는 갈래(profileRequired)는 남은 입력을 지우지 않습니다', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'new-user',
        locale: koreaLocale,
        overrides: [
          onboardingDraftStoreProvider.overrideWith(
            (ref) => _SeededDraftStore(
              ref.watch(appDatabaseProvider),
              _completeDraft,
            ),
          ),
        ],
      );
      await tester.runAsync(
        () => container.read(onboardingDraftProvider.future),
      );
      await tester.pumpAndSettle();
      expect(container.read(onboardingDraftProvider).value, _completeDraft);
    });
  });

  group('뒤로 버튼은 돌아갈 화면이 있을 때만 보입니다', () {
    testWidgets('갈래의 첫 화면(onboard-call, profileRequired)은 뒤로 버튼이 없습니다', (
      tester,
    ) async {
      await pumpApp(tester, scenario: 'profile-required', locale: koreaLocale);
      await pumpUntilScreen(tester, ScreenIds.onboardCall);
      expect(_back, findsNothing);
    });

    testWidgets('welcome에서 연 onboard-call과 다음 단계는 뒤로 버튼이 있습니다', (tester) async {
      await pumpApp(tester, scenario: 'new-user', locale: koreaLocale);
      await tester.tap(_screen(SlotIds.welcomeCtaStart));
      await tester.pumpAndSettle();
      expect(_screen(ScreenIds.onboardCall), findsOneWidget);
      expect(_back, findsOneWidget);

      await tester.enterText(find.byType(EditableText), '별님');
      await tester.pump();
      await tapNext(tester);
      expect(_screen(ScreenIds.onboardBirth), findsOneWidget);
      expect(_back, findsOneWidget);
      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(_screen(ScreenIds.onboardCall), findsOneWidget);
    });
  });

  testWidgets('입력이 덜 찬 채 preview로 오면 다시 시도 대신 onboard-call', (tester) async {
    final container = await pumpApp(
      tester,
      scenario: 'new-user',
      locale: koreaLocale,
    );
    container.read(routerProvider).go(pathOf(ScreenIds.preview));
    await pumpUntilScreen(tester, ScreenIds.onboardCall);

    expect(_screen(ScreenIds.preview), findsNothing);
    expect(_fake(container).callCountOf('createPreview'), 0);
  });

  testWidgets('저장 거절 안내는 로그아웃하면 비웁니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'member');
    container
        .read(onboardingRejectionNoticeProvider.notifier)
        .leave(const OfflineError());

    await tester.runAsync(() => container.read(tokenStoreProvider).signOut());
    await tester.pumpAndSettle();

    expect(container.read(onboardingRejectionNoticeProvider), isNull);
  });
}
