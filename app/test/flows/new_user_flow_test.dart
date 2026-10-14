import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/features/auth/presentation/consent_screen.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

Finder _screen(String id) => find.byKey(ValueKey(id));

/// 광고 동의 SDK 호출 수를 세는 대역.
class _CountingAdConsent implements AdConsent {
  int gathers = 0;

  @override
  Future<AdConsentResult> gather() async {
    gathers++;
    return AdConsentResult.personalized;
  }
}

Future<void> _checkDocument(
  WidgetTester tester,
  ConsentDocumentDocumentEnum document,
) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(consentDocumentKey(document)),
      matching: find.byType(CheckRow),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new-user: welcome에서 today까지 계정 만들기 전체 흐름', (tester) async {
    covers(
      const Covers(
        exits: [
          'welcome>onboard-call',
          'onboard-call>onboard-birth',
          'onboard-birth>onboard-time',
          'onboard-time>onboard-gender',
          'onboard-gender>preview',
          'preview>login',
          'login>consent',
          'consent>notify-ask',
          'notify-ask>ad-consent',
          'ad-consent>today',
        ],
        decisions: ['D50', 'D53'],
      ),
    );
    final adConsent = _CountingAdConsent();
    final container = await pumpApp(
      tester,
      scenario: 'new-user',
      locale: koreaLocale,
      overrides: [adConsentProvider.overrideWithValue(adConsent)],
    );

    // welcome → 호칭 → 생일 → 시간 → 성별 → 미리보기
    expect(_screen(ScreenIds.welcome), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(SlotIds.welcomeCtaStart)));
    await tester.pumpAndSettle();
    expect(_screen(ScreenIds.onboardCall), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '별님');
    await tester.pump();
    await tapNext(tester);
    expect(_screen(ScreenIds.onboardBirth), findsOneWidget);
    await tapNext(tester);
    expect(_screen(ScreenIds.onboardTime), findsOneWidget);
    await tapNext(tester);
    expect(_screen(ScreenIds.onboardGender), findsOneWidget);
    await tester.tap(find.text(_ko.genderFemale));
    await tester.pumpAndSettle();
    await tapNext(tester);
    expect(_screen(ScreenIds.preview), findsOneWidget);
    await settlePreview(tester);

    // 미리보기 → 로그인 → 동의
    await tester.tap(_screen(SlotIds.previewCtaSave));
    await tester.pumpAndSettle();
    expect(_screen(ScreenIds.login), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is SocialLoginButton && w.provider == SocialProvider.kakao,
      ),
    );
    await pumpUntilScreen(tester, ScreenIds.consent);
    await _checkDocument(tester, ConsentDocumentDocumentEnum.terms);
    await _checkDocument(tester, ConsentDocumentDocumentEnum.privacy);

    // 동의 → 프로필 저장 → 알림 → 광고 동의 → today
    await tester.tap(
      find.descendant(
        of: _screen(ScreenIds.consent),
        matching: find.byType(PrimaryButton),
      ),
    );
    await pumpUntilScreen(tester, ScreenIds.notifyAsk);
    await tester.tap(
      find.descendant(
        of: find.byType(InputStep),
        matching: find.byType(PrimaryButton),
      ),
    );
    await pumpUntilScreen(tester, ScreenIds.today);

    expect(adConsent.gathers, 1);
    expect(
      container.read(onboardingDraftProvider).value,
      const OnboardingDraft(),
    );
    final profile = await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    );
    expect(profile?.currentTimezone, 'Asia/Seoul');
  });
}
