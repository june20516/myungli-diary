import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' show expect, find;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

void main() {
  patrolTest('새 사용자: welcome에서 today까지 계정을 만듭니다', ($) async {
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
    // 한국 기기 흐름(출생지 입력 없음, D29)을 기기 설정과 상관없이 확인합니다.
    final container = await launchApp(
      $,
      flow: 'onboarding',
      scenario: 'new-user',
      deviceLocale: const Locale('ko', 'KR'),
    );

    await expectScreen($, ScreenIds.welcome);
    await $(find.byKey(const ValueKey(SlotIds.welcomeCtaStart))).tap();

    await expectScreen($, ScreenIds.onboardCall);
    await $(EditableText).enterText('별님');
    await $(PrimaryButton).tap();

    await expectScreen($, ScreenIds.onboardBirth);
    await $(PrimaryButton).tap();

    await expectScreen($, ScreenIds.onboardTime);
    await $(PrimaryButton).tap();

    await expectScreen($, ScreenIds.onboardGender);
    // 문구에 기대지 않게 Key로 찾습니다(0번 = 여성).
    await $(find.byKey(Segmented.itemKey(0))).tap();
    await $(PrimaryButton).tap();

    await expectScreen($, ScreenIds.preview);
    await $(find.byKey(const ValueKey(SlotIds.previewCtaSave))).tap();

    await expectScreen($, ScreenIds.login);
    await $(SocialLoginButton).first.tap();

    await expectScreen($, ScreenIds.consent);
    await $(CheckRow).at(0).tap();
    await $(CheckRow).at(1).tap();
    await $(
      find.descendant(
        of: find.byKey(const ValueKey(ScreenIds.consent)),
        matching: find.byType(PrimaryButton),
      ),
    ).tap();

    await expectScreen($, ScreenIds.notifyAsk);
    await $(
      find.descendant(
        of: find.byType(InputStep),
        matching: find.byType(PrimaryButton),
      ),
    ).tap();

    await expectScreen($, ScreenIds.today);
    // 프로필 저장이 끝나면 온보딩 입력은 비워집니다.
    expect(
      container.read(onboardingDraftProvider).value,
      const OnboardingDraft(),
    );
  });
}
