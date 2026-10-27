import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart'
    show Finder, expect, find, findsNothing;
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/features/account/presentation/account_merge_screen.dart';
import 'package:myungli_diary/features/account/presentation/login_methods_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

/// [provider]의 `social-login-button`.
Finder _button(SocialProvider provider) => find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == provider,
);

bool _connected(PatrolIntegrationTester $, SocialProvider provider) =>
    $.tester.widget<SocialLoginButton>(_button(provider)).connected;

/// [done]이 참이 될 때까지 프레임을 돌립니다(대역 서버 응답을 기다림).
Future<void> _waitUntil(
  PatrolIntegrationTester $,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('$timeout 안에 조건을 만족하지 못했습니다');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  patrolTest('설정 > 로그인 수단: LINE 붙이기, 이미 쓰는 Google 안내, 계정 합치기', ($) async {
    covers(
      const Covers(
        exits: [
          'settings>login-methods',
          'login-methods>account-merge',
          'account-merge>login-methods',
        ],
        states: ['login-methods:error'],
        decisions: ['D82', 'D85'],
      ),
    );
    final container = await launchApp($, flow: 'account', scenario: 'member');

    // today에서 설정까지의 길은 me 흐름이 덮으므로 경로로 바로 들어갑니다.
    await waitForScreen($, ScreenIds.today);
    unawaited(
      container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
    );
    await waitForScreen($, ScreenIds.settings);
    await $(find.byKey(SettingsScreen.loginMethodsRowKey)).scrollTo().tap();

    await expectScreen($, ScreenIds.loginMethods);
    await _waitUntil(
      $,
      () => _button(SocialProvider.kakao).evaluate().isNotEmpty,
    );
    expect(_connected($, SocialProvider.line), false);

    // LINE 붙이기: 목록에 LINE이 생깁니다.
    await $(_button(SocialProvider.line)).tap();
    await _waitUntil($, () => _connected($, SocialProvider.line));

    // Google 붙이기: 다른 계정이 쓰는 인증 수단이라 안내만 뜨고 화면에 남습니다.
    await $(_button(SocialProvider.google)).tap();
    await $(find.byKey(const ValueKey(SlotIds.loginMethodsInUseBody)))
        .waitUntilVisible();
    await $.tap(find.text('확인'));
    expect(_connected($, SocialProvider.google), false);

    // 합치기 입구 > 인증(연결하지 않은 Google) > 요약
    await $(find.byKey(LoginMethodsScreen.mergeCtaKey)).scrollTo().tap();
    await expectScreen($, ScreenIds.accountMerge);
    await $(_button(SocialProvider.google)).tap();
    await $(find.byKey(AccountChoice.cardKey(1))).waitUntilVisible();

    // 다른 계정 프로필을 고르고 확인하면 login-methods로 돌아갑니다.
    await $(find.byKey(AccountChoice.cardKey(1))).tap();
    await $(find.byKey(AccountMergeScreen.mergeCtaKey)).scrollTo().tap();
    await $.tap(find.text('합치기').last);
    await _waitUntil(
      $,
      () =>
          find.byKey(const ValueKey(ScreenIds.accountMerge)).evaluate().isEmpty,
    );
    await waitForScreen($, ScreenIds.loginMethods);
    expect(find.byKey(const ValueKey(ScreenIds.accountMerge)), findsNothing);
    expect(_connected($, SocialProvider.line), true);
  });
}
