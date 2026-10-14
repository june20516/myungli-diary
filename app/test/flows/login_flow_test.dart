import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/features/auth/presentation/login_screen.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Finder _screen(String id) => find.byKey(ValueKey(id));

final Finder _kakaoButton = find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == SocialProvider.kakao,
);

/// 광고 동의 SDK 호출 수를 세는 대역.
class _CountingAdConsent implements AdConsent {
  int gathers = 0;

  @override
  Future<AdConsentResult> gather() async {
    gathers++;
    return AdConsentResult.personalized;
  }
}

/// 실제 I/O와 프레임을 번갈아 돌며 [done]이 참이 될 때까지 기다립니다.
///
/// 처리 중 점이 계속 숨 쉬어 `pumpAndSettle`이 끝나지 않으므로 고정 간격으로 프레임을 줍니다.
/// [settle]이 false면(아직 처리 중) 마지막에 열림 움직임이 끝날 만큼만 프레임을 줍니다.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  bool settle = true,
}) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (done()) {
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 500));
      }
      return;
    }
  }
  fail('기다리던 화면이 오지 않음');
}

/// 처리 중 점이 사라질 때까지(요청과 진입 갱신이 끝날 때까지) 기다립니다.
Future<void> _settleLogin(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _pumpUntil(
    tester,
    () => find.byKey(SocialLoginButton.dotsKey).evaluate().isEmpty,
  );
  await settleTimezoneSync(tester, container);
  await tester.pumpAndSettle();
}

/// welcome의 "이미 계정이 있어요"로 login까지 갑니다.
Future<void> _openLoginFromWelcome(WidgetTester tester) async {
  await tester.tap(_screen(SlotIds.welcomeCtaSignin));
  await tester.pumpAndSettle();
  expect(_screen(ScreenIds.login), findsOneWidget);
}

void main() {
  testWidgets('new-user: 미리보기 뒤 카카오 로그인 → 새 계정이라 consent', (tester) async {
    covers(const Covers(exits: ['login>consent'], decisions: ['D50']));
    final container = await openPreviewStep(tester);
    await tester.tap(_screen(SlotIds.previewCtaSave));
    await tester.pumpAndSettle();
    expect(_screen(ScreenIds.login), findsOneWidget);
    expect(_screen(SlotIds.loginTitleHead), findsOneWidget);
    expect(_screen(SlotIds.loginTitleBody), findsOneWidget);

    await tester.tap(_kakaoButton);
    await _settleLogin(tester, container);

    expect(_screen(ScreenIds.consent), findsOneWidget);
    expect(_fake(container).callCountOf('loginKakao'), 1);
    expect(container.read(tokenStoreProvider).accessToken, isNotNull);
    // 새 계정은 약관 동의 뒤 프로필 저장에 입력을 쓰므로 남깁니다.
    expect(
      container.read(onboardingDraftProvider).value,
      isNot(const OnboardingDraft()),
    );
  });

  testWidgets('returning-user: 입력이 없으면 광고 동의를 한 번 거쳐 today', (tester) async {
    covers(
      const Covers(
        exits: ['login>ad-consent', 'ad-consent>today', 'login>today'],
        decisions: ['D53'],
      ),
    );
    final adConsent = _CountingAdConsent();
    final container = await pumpApp(
      tester,
      scenario: 'returning-user',
      overrides: [adConsentProvider.overrideWithValue(adConsent)],
    );
    await _openLoginFromWelcome(tester);
    expect(adConsent.gathers, 0);

    await tester.tap(_kakaoButton);
    await _settleLogin(tester, container);

    expect(_screen(ScreenIds.today), findsOneWidget);
    expect(adConsent.gathers, 1);
    expect(_screen(SlotIds.loginDiscardNotice), findsNothing);
  });

  testWidgets('returning-user: 이 기기에서 광고 동의를 이미 했으면 바로 today', (tester) async {
    covers(const Covers(exits: ['login>today']));
    final adConsent = _CountingAdConsent();
    final container = await pumpApp(
      tester,
      scenario: 'returning-user',
      overrides: [adConsentProvider.overrideWithValue(adConsent)],
    );
    await tester.runAsync(
      () => container
          .read(deviceFlagsStoreProvider)
          .writeBool(adConsentDoneKey, value: true),
    );
    await _openLoginFromWelcome(tester);

    await tester.tap(_kakaoButton);
    await _settleLogin(tester, container);

    expect(_screen(ScreenIds.today), findsOneWidget);
    expect(adConsent.gathers, 0);
  });

  testWidgets('returning-user: 미리보기 입력이 있으면 쓰지 않는다는 안내 뒤 입력을 지우고 today', (
    tester,
  ) async {
    covers(const Covers(exits: ['login>ad-consent', 'login>today']));
    final container = await openPreviewStep(tester, scenario: 'returning-user');
    await tester.tap(_screen(SlotIds.previewCtaSave));
    await tester.pumpAndSettle();

    await tester.tap(_kakaoButton);
    await _pumpUntil(
      tester,
      () => _screen(SlotIds.loginDiscardNotice).evaluate().isNotEmpty,
      // 안내가 열린 동안 버튼은 처리 중이라 점이 계속 움직입니다.
      settle: false,
    );
    expect(find.text(_ko.loginDiscardNotice), findsOneWidget);
    // 안내를 닫기 전에는 이동하지 않습니다.
    expect(_screen(ScreenIds.login), findsOneWidget);

    await tester.tap(find.text(_ko.actionConfirm));
    await _settleLogin(tester, container);

    expect(_screen(ScreenIds.today), findsOneWidget);
    expect(
      container.read(onboardingDraftProvider).value,
      const OnboardingDraft(),
    );
    final saved = await tester.runAsync(
      () => container.read(onboardingDraftStoreProvider).read(),
    );
    expect(saved, isNull);
  });

  testWidgets('login-provider-down: 재시도 안내, 토큰 없음, 다시 누르면 다시 요청', (
    tester,
  ) async {
    covers(const Covers(states: ['login:error']));
    final container = await pumpApp(tester, scenario: 'login-provider-down');
    await _openLoginFromWelcome(tester);

    await tester.tap(_kakaoButton);
    await _settleLogin(tester, container);

    expect(_screen(ScreenIds.login), findsOneWidget);
    expect(find.byKey(loginErrorKey), findsOneWidget);
    expect(find.text(_ko.errorAuthProviderUnavailable), findsOneWidget);
    expect(container.read(tokenStoreProvider).accessToken, isNull);
    expect(_fake(container).callCountOf('loginKakao'), 1);

    await tester.tap(_kakaoButton);
    await _settleLogin(tester, container);

    expect(_fake(container).callCountOf('loginKakao'), 2);
    expect(find.byKey(loginErrorKey), findsOneWidget);
  });

  testWidgets(
    'login-entry-unavailable: 로그인 뒤 진입 계산이 실패하면 안내하고, 다시 누르면 consent',
    (tester) async {
      covers(const Covers(states: ['login:error']));
      final container = await pumpApp(
        tester,
        scenario: 'login-entry-unavailable',
      );
      await _openLoginFromWelcome(tester);

      await tester.tap(_kakaoButton);
      await _settleLogin(tester, container);

      // 화면이 아무 안내 없이 멈추지 않고 실패를 알립니다.
      expect(_screen(ScreenIds.login), findsOneWidget);
      expect(find.byKey(loginErrorKey), findsOneWidget);
      expect(find.text(_ko.errorServiceUnavailable), findsOneWidget);
      expect(_fake(container).callCountOf('getMe'), 1);

      await tester.tap(_kakaoButton);
      await pumpUntilScreen(tester, ScreenIds.consent);
      expect(_fake(container).callCountOf('loginKakao'), 2);
    },
  );

  testWidgets('카카오 취소는 오류 상태에 취소 안내를 보입니다', (tester) async {
    covers(const Covers(states: ['login:error']));
    final container = await pumpApp(
      tester,
      scenario: 'new-user',
      overrides: [
        kakaoAuthProvider.overrideWithValue(
          FakeKakaoAuth(failWith: const SocialSignInCancelled()),
        ),
      ],
    );
    await _openLoginFromWelcome(tester);

    await tester.tap(_kakaoButton);
    await _settleLogin(tester, container);

    expect(find.byKey(loginErrorKey), findsOneWidget);
    expect(find.text(_ko.loginCancelled), findsOneWidget);
    expect(_fake(container).callCountOf('loginKakao'), 0);
  });

  testWidgets(
    'login-exchange-invalid: Android Apple 웹 교환 코드가 만료되면 처음부터 다시 안내',
    (tester) async {
      covers(const Covers(states: ['login:error']));
      final container = await pumpApp(
        tester,
        scenario: 'login-exchange-invalid',
        overrides: [
          targetPlatformProvider.overrideWithValue(TargetPlatform.android),
        ],
      );
      await _openLoginFromWelcome(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is SocialLoginButton && w.provider == SocialProvider.apple,
        ),
      );
      await _settleLogin(tester, container);

      expect(find.text(_ko.errorAuthExchangeInvalid), findsOneWidget);
      expect(_fake(container).callCountOf('completeAppleWebLogin'), 1);
      expect(_fake(container).callCountOf('loginApple'), 0);
      expect(container.read(tokenStoreProvider).accessToken, isNull);
    },
  );

  testWidgets('Android Apple 웹 로그인을 취소하면 취소 안내를 보이고 server를 부르지 않습니다', (
    tester,
  ) async {
    covers(const Covers(states: ['login:error']));
    final container = await pumpApp(
      tester,
      scenario: 'new-user',
      overrides: [
        targetPlatformProvider.overrideWithValue(TargetPlatform.android),
        appleWebAuthProvider.overrideWithValue(
          FakeAppleWebAuth(
            returnQuery: const {'error': 'user_cancelled_authorize'},
          ),
        ),
      ],
    );
    await _openLoginFromWelcome(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is SocialLoginButton && w.provider == SocialProvider.apple,
      ),
    );
    await _settleLogin(tester, container);

    expect(find.byKey(loginErrorKey), findsOneWidget);
    expect(find.text(_ko.appleWebErrorCancelled), findsOneWidget);
    expect(_fake(container).callCountOf('completeAppleWebLogin'), 0);
    expect(container.read(tokenStoreProvider).accessToken, isNull);
  });

  testWidgets('버튼을 빠르게 두 번 눌러도 loginKakao 요청은 한 번입니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'new-user');
    await _openLoginFromWelcome(tester);

    await tester.tap(_kakaoButton);
    await tester.tap(_kakaoButton, warnIfMissed: false);
    await tester.pump();
    await tester.tap(_kakaoButton, warnIfMissed: false);
    await _settleLogin(tester, container);

    expect(_fake(container).callCountOf('loginKakao'), 1);
    expect(_screen(ScreenIds.consent), findsOneWidget);
  });
}
