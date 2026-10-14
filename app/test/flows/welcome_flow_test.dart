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
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey(SlotIds.welcomeCtaSignin)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.login)), findsOneWidget);
  });

  testWidgets('큰 글자·작은 화면에서도 넘치지 않고 버튼에 닿습니다', (tester) async {
    for (final scale in [2.0, 3.0]) {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, scenario: 'new-user');

      final button = find.byKey(const ValueKey(SlotIds.welcomeCtaSignin));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '글자 배율 $scale');
      expect(button, findsOneWidget);
    }
  });
}
