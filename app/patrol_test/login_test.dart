import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' show find;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

void main() {
  patrolTest('기존 사용자: welcome에서 로그인하면 today로 갑니다', ($) async {
    covers(
      const Covers(
        exits: ['welcome>login', 'login>ad-consent', 'ad-consent>today'],
        decisions: ['D50'],
      ),
    );
    await launchApp($, scenario: 'returning-user');

    await expectScreen($, ScreenIds.welcome);
    await $(find.byKey(const ValueKey(SlotIds.welcomeCtaSignin))).tap();

    await expectScreen($, ScreenIds.login);
    await $(SocialLoginButton).first.tap();

    await expectScreen($, ScreenIds.today);
  });
}
