import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('force-update 버튼은 스토어를 열고 뒤로 가기로 벗어날 수 없습니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'force-update');

    expect(find.byKey(const ValueKey(ScreenIds.forceUpdate)), findsOneWidget);
    expect(
      find.byKey(const ValueKey(SlotIds.forceUpdateNoticeHead)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(SlotIds.forceUpdateNoticeBody)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey(SlotIds.forceUpdateCtaStore)));
    await tester.pump();
    final launcher = container.read(storeLauncherProvider) as FakeStoreLauncher;
    expect(launcher.opened, 1);

    // 시스템 뒤로 가기를 보내도 화면이 남습니다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.forceUpdate)), findsOneWidget);
    expect(SystemNavigator.routeInformationUpdated, isNotNull);
  });
}
