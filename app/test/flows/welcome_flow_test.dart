import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('welcome 시작하기는 onboard-call로, 이미 계정이 있어요는 login으로 갑니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['welcome>onboard-call', 'welcome>login']));
    await pumpApp(tester, scenario: 'new-user');

    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
    expect(
      find.byKey(const ValueKey(SlotIds.welcomeConceptHead)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(SlotIds.welcomeConceptBody)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey(SlotIds.welcomeCtaStart)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);

    // 뒤로 오면 welcome입니다(push 이동).
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey(SlotIds.welcomeCtaSignin)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.login)), findsOneWidget);
  });
}
