import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart' show pumpUntilScreen;

final _ko = AppLocalizationsKo();

void main() {
  testWidgets('today: app-bar 제목을 today.bar.title 슬롯과 원고 글자로 그립니다', (
    tester,
  ) async {
    await pumpApp(tester, scenario: 'member');
    await pumpUntilScreen(tester, ScreenIds.today);

    expectAppBarTitle(SlotIds.todayBarTitle, _ko.todayBarTitle);
    // 탭 라벨(tabToday)은 tab-bar에 그대로 둡니다.
    expect(
      find.descendant(
        of: find.byType(TabBarRow),
        matching: find.text(_ko.tabToday),
      ),
      findsOneWidget,
    );
  });
}
