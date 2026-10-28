import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';

import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';

void main() {
  testWidgets('로그인 수단 줄을 누르면 login-methods', (tester) async {
    final container = await pumpApp(tester, scenario: 'member');
    unawaited(
      container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
    );
    await pumpUntilScreen(tester, ScreenIds.settings);
    await settleWithIo(tester);

    final row = tester.widget<SettingsRow>(
      find.byKey(SettingsScreen.loginMethodsRowKey),
    );
    expect(row.label, AppLocalizationsKo().loginMethodsBarTitle);
    expect(row.variant, SettingsRowVariant.navigate);

    await tester.tap(find.byKey(SettingsScreen.loginMethodsRowKey));
    await pumpUntilScreen(tester, ScreenIds.loginMethods);
    await settleWithIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.loginMethods)), findsOneWidget);
  });
}
