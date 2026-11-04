import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show Finder, find;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/contact/presentation/contact_screen.dart';
import 'package:myungli_diary/features/me/presentation/my_saju_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

/// 입력칸 key 아래의 실제 입력 위젯.
Finder _field(String slotId) => find.descendant(
  of: find.byKey(ValueKey(slotId)),
  matching: find.byType(EditableText),
);

void main() {
  patrolTest('설정 > 문의: 내용과 메일을 적어 보내면 설정에서 보냈다는 toast', ($) async {
    covers(
      const Covers(
        exits: ['settings>contact', 'contact>settings'],
        decisions: ['D102'],
      ),
    );
    // toast 문구를 글자로 찾으므로 표시 언어를 한국어로 고정합니다.
    await launchApp(
      $,
      flow: 'contact',
      scenario: 'member',
      deviceLocale: const Locale('ko', 'KR'),
    );
    await waitForScreen($, ScreenIds.today);

    // 나 탭 > 톱니 > 설정 > 문의.
    await $(find.byKey(const ValueKey('tab-bar.tab.3'))).tap();
    await waitForScreen($, ScreenIds.mySaju);
    await $(find.byKey(MySajuScreen.settingsKey)).tap();
    await waitForScreen($, ScreenIds.settings);
    final l10n = AppLocalizations.of(
      $.tester.element(find.byKey(const ValueKey(ScreenIds.settings))),
    );
    await $(find.byKey(SettingsScreen.contactRowKey)).scrollTo().tap();
    await expectScreen($, ScreenIds.contact);

    // staging에서는 실제 메일이 가므로 내용 첫머리를 [E2E]로 둡니다.
    await $.tester.enterText(
      _field(SlotIds.contactMessageField),
      '[E2E] 자동 시험 문의입니다.',
    );
    await $.tester.enterText(
      _field(SlotIds.contactEmailField),
      'e2e@example.com',
    );
    await $.pumpAndTrySettle();

    // 보내면 설정으로 돌아와 그 화면에서 toast를 보입니다.
    await $(find.byKey(ContactScreen.sendKey)).tap();
    await waitForScreen($, ScreenIds.settings);
    // toast는 누름을 통과시키므로(IgnorePointer) hit test 대신 존재로 기다립니다.
    await waitUntil(
      $,
      () => find.text(l10n.contactSentToast).evaluate().isNotEmpty,
    );
    await expectScreen($, ScreenIds.settings, state: 'contact-sent');
  });
}
