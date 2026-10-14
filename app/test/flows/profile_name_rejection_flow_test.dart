import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Finder _screen(String id) => find.byKey(ValueKey(id));

final Finder _kakaoButton = find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == SocialProvider.kakao,
);

Finder get _callNext => find.descendant(
  of: _screen(ScreenIds.onboardCall),
  matching: find.byType(PrimaryButton),
);

bool _callNextEnabled(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_callNext).onPressed != null;

String _honorificText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

bool _fieldShowsError(WidgetTester tester) =>
    tester.widget<MyungliTextField>(find.byType(MyungliTextField)).error;

/// login에서 카카오로 로그인하고 약관에 모두 동의합니다.
Future<void> _signInAndAgree(WidgetTester tester) async {
  await tester.tap(_kakaoButton);
  await pumpUntilScreen(tester, ScreenIds.consent);
  for (final label in [
    _ko.consentRequiredLabelTerms,
    _ko.consentRequiredLabelPrivacy,
  ]) {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }
  await tester.tap(
    find.descendant(
      of: _screen(ScreenIds.consent),
      matching: find.byType(PrimaryButton),
    ),
  );
}

/// 오류 줄이 붙은 onboard-call에서 호칭을 고쳐 다시 저장하고 notify-ask에 닿는지 확인합니다.
Future<void> _fixHonorificAndFinish(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.enterText(find.byType(EditableText), '달님');
  await tester.pumpAndSettle();
  // 글자를 고치면 오류 줄이 사라지고 다음이 켜집니다.
  expect(find.text(_ko.errorNameEmoji), findsNothing);
  expect(_fieldShowsError(tester), isFalse);
  expect(_callNextEnabled(tester), isTrue);

  // 입력이 완전하므로 다음이 곧 다시 저장입니다.
  await tester.tap(_callNext);
  await pumpUntilScreen(tester, ScreenIds.notifyAsk);
  expect(_fake(container).callCountOf('createProfile'), 2);
}

void main() {
  testWidgets(
    'profile-name-invalid(동의 직후 저장): 호칭 422는 onboard-call 호칭 칸 아래 오류 줄',
    (tester) async {
      final container = await openPreviewStep(
        tester,
        scenario: 'profile-name-invalid',
      );
      await tester.tap(_screen(SlotIds.previewCtaSave));
      await tester.pumpAndSettle();
      await _signInAndAgree(tester);
      await pumpUntilScreen(tester, ScreenIds.onboardCall);
      await tester.pumpAndSettle();

      expect(_fake(container).callCountOf('createProfile'), 1);
      expect(find.text(_ko.errorNameEmoji), findsOneWidget);
      expect(_fieldShowsError(tester), isTrue);
      expect(_callNextEnabled(tester), isFalse);
      expect(_honorificText(tester), '별님');
      expect(container.read(onboardingRejectionNoticeProvider), isNull);

      await _fixHonorificAndFinish(tester, container);
    },
  );

  testWidgets('profile-name-invalid(로그인한 채 마친 온보딩): '
      '성별 다음의 호칭 422는 onboard-call로 돌아가 오류 줄', (tester) async {
    final container = await pumpApp(
      tester,
      scenario: 'profile-name-invalid',
      locale: koreaLocale,
    );
    await tester.tap(_screen(SlotIds.welcomeCtaSignin));
    await tester.pumpAndSettle();
    await _signInAndAgree(tester);
    await pumpUntilScreen(tester, ScreenIds.onboardCall);

    await tester.enterText(find.byType(EditableText), '별님');
    await tester.pump();
    await tapNext(tester); // 호칭 → 생일
    await tapNext(tester); // 생일 → 시간
    await tapNext(tester); // 시간 → 성별
    await tester.tap(find.text(_ko.genderFemale));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: _screen(ScreenIds.onboardGender),
        matching: find.byType(PrimaryButton),
      ),
    );
    await pumpUntil(
      tester,
      () => find.text(_ko.errorNameEmoji).evaluate().isNotEmpty,
    );

    // 성별 화면의 toast가 아니라 첫 단계의 호칭 칸에 붙습니다.
    expect(_screen(ScreenIds.onboardGender), findsNothing);
    expect(_screen(ScreenIds.onboardCall), findsOneWidget);
    expect(_fake(container).callCountOf('createProfile'), 1);
    expect(_fieldShowsError(tester), isTrue);
    expect(_callNextEnabled(tester), isFalse);
    expect(_honorificText(tester), '별님');
    expect(container.read(onboardingDraftProvider).value!.gender, isNotNull);
    expect(container.read(onboardingRejectionNoticeProvider), isNull);
    // 오류 줄은 사라지지 않고 남습니다(toast처럼 몇 초 뒤 사라지지 않음).
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text(_ko.errorNameEmoji), findsOneWidget);
    expect(find.byType(CheckRow), findsNothing);

    await _fixHonorificAndFinish(tester, container);
  });
}
