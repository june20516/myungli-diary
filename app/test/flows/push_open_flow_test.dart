import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('꺼진 앱을 아침 알림으로 열면 진입 계산 뒤 today에 닿습니다', (tester) async {
    covers(const Covers(exits: ['system-push>today'], decisions: ['D50']));
    final push = FakePushMessaging(initial: PushOpen.tryCreate('today'));
    await pumpApp(
      tester,
      scenario: 'member',
      overrides: [pushMessagingProvider.overrideWithValue(push)],
    );

    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
  });

  testWidgets('알림이 연 화면이 첫 화면이 아니어도 진입 계산 뒤 그 화면으로 돌아갑니다', (tester) async {
    final push = FakePushMessaging(initial: PushOpen.tryCreate('calendar'));
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [pushMessagingProvider.overrideWithValue(push)],
    );

    final router = container.read(routerProvider);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/calendar');
    expect(find.byKey(const ValueKey(ScreenIds.calendar)), findsOneWidget);
  });

  testWidgets('로그아웃 상태에서 알림으로 열면 welcome입니다', (tester) async {
    final push = FakePushMessaging(initial: PushOpen.tryCreate('today'));
    await pumpApp(
      tester,
      scenario: 'new-user',
      overrides: [pushMessagingProvider.overrideWithValue(push)],
    );

    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsNothing);
  });

  testWidgets('실행 중 알림을 누르면 today로 갑니다', (tester) async {
    covers(const Covers(exits: ['system-push>today']));
    final push = FakePushMessaging();
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [pushMessagingProvider.overrideWithValue(push)],
    );
    final router = container.read(routerProvider)..go('/calendar');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/calendar');

    push.addOpen(PushOpen.tryCreate('today')!);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/today');
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
  });
}
