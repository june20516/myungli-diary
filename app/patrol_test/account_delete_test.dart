import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show find;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/me/presentation/my_saju_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/features/profile/presentation/account_delete_screen.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

void main() {
  patrolTest('설정 > 계정 삭제: 확인하면 계정이 지워지고 welcome', ($) async {
    covers(
      const Covers(
        exits: ['settings>account-delete', 'account-delete>welcome'],
      ),
    );
    // 확인 창 문구를 글자로 찾으므로 표시 언어를 한국어로 고정합니다.
    await launchApp(
      $,
      flow: 'account-delete',
      scenario: 'member',
      deviceLocale: const Locale('ko', 'KR'),
    );
    await waitForScreen($, ScreenIds.today);

    // 나 탭 > 톱니 > 설정 > 계정 삭제.
    await $(find.byKey(const ValueKey('tab-bar.tab.3'))).tap();
    await waitForScreen($, ScreenIds.mySaju);
    await $(find.byKey(MySajuScreen.settingsKey)).tap();
    await waitForScreen($, ScreenIds.settings);
    final l10n = AppLocalizations.of(
      $.tester.element(find.byKey(const ValueKey(ScreenIds.settings))),
    );
    await $(find.byKey(SettingsScreen.accountDeleteRowKey)).scrollTo().tap();
    await expectScreen($, ScreenIds.accountDelete);

    // 삭제 > 확인 창 > 삭제 > welcome.
    await $(find.byKey(AccountDeleteScreen.deleteKey)).scrollTo().tap();
    await $(find.text(l10n.accountDeleteDeleteConfirm)).waitUntilVisible();
    await $(find.text(l10n.accountDeleteDeleteConfirmDelete).last).tap();
    await expectScreen($, ScreenIds.welcome);
  });
}
