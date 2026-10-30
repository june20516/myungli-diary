import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/app/profile_timezone.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

import '../support/app_harness.dart';
import '../support/profile_sync_harness.dart';

Future<void> _resume(WidgetTester tester, ProviderContainer container) async {
  // 실제 시계 영역에서 보내야 DB·통신 await 사슬이 끝까지 돕니다.
  await tester.runAsync(() async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  await settleTimezoneSync(tester, container);
}

/// 진입 갈래를 테스트가 바꿀 수 있게 쥐고 있는 notifier.
class _EntryHolder extends Notifier<EntryState?> {
  @override
  EntryState? build() => EntryState.signedOut;

  // ignore: use_setters_to_change_properties, 테스트가 호출하는 설정 함수
  void set(EntryState? value) => state = value;
}

final _entryHolderProvider = NotifierProvider<_EntryHolder, EntryState?>(
  _EntryHolder.new,
);

void main() {
  testWidgets('resumed에서 기기 시간대가 사본과 다르면 PATCH를 보낸다', (tester) async {
    final device = MutableDeviceTimezone('Asia/Seoul');
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Seoul',
      deviceSource: device,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppLifecycleHooks(child: SizedBox()),
      ),
    );
    await settleTimezoneSync(tester, container);
    await _resume(tester, container);
    expect(server.bodies, isEmpty);

    device.value = 'America/Los_Angeles';
    await _resume(tester, container);
    expect(server.bodies, [
      {'currentTimezone': 'America/Los_Angeles'},
    ]);
  });

  testWidgets('사본이 없어도 resumed 뒤 profileTimezoneProvider가 새 기기 시간대다', (
    tester,
  ) async {
    final device = MutableDeviceTimezone('Asia/Seoul');
    final (container, _, _) = await setUpSync(
      tester,
      device: 'Asia/Seoul',
      deviceSource: device,
      seed: false,
      overrides: [
        // 자식 컨테이너의 기기 시간대를 보게 다시 묶습니다.
        deviceTimezoneNameProvider.overrideWith(
          (ref) => ref.watch(deviceTimezoneProvider).current(),
        ),
        ...profileTimezoneOverrides,
      ],
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AppLifecycleHooks(child: SizedBox()),
        ),
      );
    });
    await settleTimezoneSync(tester, container);
    // 앱에서는 todayProvider가 구독하고 있으므로 같은 조건을 만듭니다.
    container.listen(profileTimezoneProvider, (_, _) {});
    await settleTimezoneSync(tester, container);
    expect(container.read(profileTimezoneProvider), 'Asia/Seoul');
    device.value = 'America/Los_Angeles';
    await _resume(tester, container);
    await settleTimezoneSync(tester, container);
    expect(container.read(profileTimezoneProvider), 'America/Los_Angeles');
  });

  testWidgets('이미 ready로 시작해도 한 번 동기화한다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AppLifecycleHooks(child: SizedBox()),
        ),
      );
    });
    await settleTimezoneSync(tester, container);
    expect(server.bodies, [
      {'currentTimezone': 'Asia/Tokyo'},
    ]);
  });

  testWidgets('진입이 ready로 바뀌면 한 번 동기화한다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      overrides: [
        entryProvider.overrideWith((ref) => ref.watch(_entryHolderProvider)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppLifecycleHooks(child: SizedBox()),
      ),
    );
    expect(server.bodies, isEmpty);
    await tester.runAsync(() async {
      container.read(_entryHolderProvider.notifier).set(EntryState.ready);
    });
    await settleTimezoneSync(tester, container);
    expect(server.bodies, [
      {'currentTimezone': 'Asia/Tokyo'},
    ]);
  });

  testWidgets('아침 알림 채널 이름은 앱 언어를 따르고 언어가 바뀌면 다시 만든다', (tester) async {
    final channels = FakeNotificationChannels();
    final (container, _, _) = await setUpSync(
      tester,
      device: 'Asia/Seoul',
      overrides: [notificationChannelsProvider.overrideWithValue(channels)],
    );
    Widget app(Locale locale) => UncontrolledProviderScope(
      container: container,
      child: Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: const AppLifecycleHooks(child: SizedBox()),
      ),
    );
    await tester.pumpWidget(app(const Locale('ko')));
    await tester.pump();
    await tester.pumpWidget(app(const Locale('ja')));
    await tester.pump();
    await settleTimezoneSync(tester, container);

    expect(channels.morningNames, [
      lookupAppLocalizations(const Locale('ko')).systemPushChannelMorning,
      lookupAppLocalizations(const Locale('ja')).systemPushChannelMorning,
    ]);
  });
}
