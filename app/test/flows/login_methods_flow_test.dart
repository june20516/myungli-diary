import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/features/account/presentation/account_merge_screen.dart';
import 'package:myungli_diary/features/account/presentation/login_methods_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

Finder _button(SocialProvider provider) => find.byWidgetPredicate(
  (w) => w is SocialLoginButton && w.provider == provider,
);

bool _connected(WidgetTester tester, SocialProvider provider) =>
    tester.widget<SocialLoginButton>(_button(provider)).connected;

/// 화면이 바뀌고 대역 서버 응답이 정착할 때까지 기다립니다.
Future<void> _arrive(WidgetTester tester, String screenId) async {
  await pumpUntilScreen(tester, screenId);
  await settleWithIo(tester);
}

/// [finder]가 화면에 나올 때까지 기다립니다.
Future<void> _until(WidgetTester tester, Finder finder) =>
    pumpUntil(tester, () => finder.evaluate().isNotEmpty);

void main() {
  testWidgets('설정 > 로그인 수단: 붙이기, 이미 쓰는 인증 수단 안내, 계정 합치기까지 토큰은 그대로', (
    tester,
  ) async {
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
    final container = await pumpApp(tester, scenario: 'member');
    final tokens = container.read(tokenStoreProvider);
    final accessToken = tokens.accessToken;
    final refreshToken = await tester.runAsync(tokens.refreshToken);
    expect(accessToken, isNotNull);
    final accountId = container.read(meProvider)!.accountId;

    // settings > login-methods
    unawaited(
      container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
    );
    await _arrive(tester, ScreenIds.settings);
    await tester.tap(find.byKey(SettingsScreen.loginMethodsRowKey));
    await _arrive(tester, ScreenIds.loginMethods);
    await _until(tester, _button(SocialProvider.kakao));
    expect(_connected(tester, SocialProvider.kakao), isTrue);
    expect(_connected(tester, SocialProvider.line), isFalse);

    // LINE 붙이기: 목록에 LINE이 생깁니다.
    await tester.tap(_button(SocialProvider.line));
    await pumpUntil(tester, () => _connected(tester, SocialProvider.line));
    expect(_connected(tester, SocialProvider.line), isTrue);

    // Google 붙이기: 다른 계정이 쓰는 인증 수단이라 안내만 뜨고 화면에 남습니다.
    await tester.tap(_button(SocialProvider.google));
    await _until(tester, find.text(_ko.loginMethodsInUseBody));
    expect(find.text(_ko.loginMethodsInUseBody), findsOneWidget);
    await tester.tap(find.text(_ko.actionConfirm));
    await settleWithIo(tester);
    expect(find.text(_ko.loginMethodsInUseBody), findsNothing);
    expect(find.byKey(const ValueKey(ScreenIds.loginMethods)), findsOneWidget);
    expect(_connected(tester, SocialProvider.google), isFalse);

    // 합치기 입구 > account-merge 인증(연결하지 않은 Google)
    await tester.ensureVisible(find.byKey(LoginMethodsScreen.mergeCtaKey));
    await tester.tap(find.byKey(LoginMethodsScreen.mergeCtaKey));
    await _arrive(tester, ScreenIds.accountMerge);
    expect(find.text(_ko.accountMergeAuthBody), findsOneWidget);
    await tester.tap(_button(SocialProvider.google));
    await _until(tester, find.byKey(AccountChoice.cardKey(1)));

    // 요약 > 다른 계정 프로필 고르기 > 확인
    expect(find.text(_ko.accountMergeSummaryDiaryCount(2)), findsOneWidget);
    await tester.tap(find.byKey(AccountChoice.cardKey(1)));
    await settleWithIo(tester);
    await tester.ensureVisible(find.byKey(AccountMergeScreen.mergeCtaKey));
    await tester.tap(find.byKey(AccountMergeScreen.mergeCtaKey));
    await _until(tester, find.text(_ko.accountMergeMergeConfirmMerge));
    await tester.tap(find.text(_ko.accountMergeMergeConfirmMerge));
    await _arrive(tester, ScreenIds.loginMethods);
    await pumpUntil(
      tester,
      () =>
          find.byKey(const ValueKey(ScreenIds.accountMerge)).evaluate().isEmpty,
    );

    // 합친 뒤에도 같은 계정이고 토큰은 바뀌지 않으며 목록을 다시 읽습니다.
    expect(container.read(meProvider)!.accountId, accountId);
    expect(tokens.accessToken, accessToken);
    expect(await tester.runAsync(tokens.refreshToken), refreshToken);
    expect(_connected(tester, SocialProvider.line), isTrue);

    // 가져온 광고 제거 기간이 내 정보와 설정의 광고 제거 줄에 보입니다.
    expect(container.read(meProvider)!.adFree.active, isTrue);
    container.read(routerProvider).pop();
    await _arrive(tester, ScreenIds.settings);
    final adFreeRow = tester.widget<SettingsRow>(
      find.byKey(SettingsScreen.adFreeRowKey),
    );
    expect(adFreeRow.variant, SettingsRowVariant.value);
    expect(
      adFreeRow.value,
      _ko.settingsAdFreeLabelActive(
        DateFormat.yMMMd('ko').format(DateTime(2026, 10, 25)),
      ),
    );
  });
}
