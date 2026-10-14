import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/app/profile_timezone.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

import '../support/profile_sync_harness.dart';

/// 비동기 작업(DB·대역 서버)이 끝나도록 실제 시간을 조금 흘립니다.
Future<void> _drain(WidgetTester tester) async {
  // 가짜 시계 영역에서 시작한 await 사슬은 실제 I/O와 microtask 처리를 번갈아 거쳐야 끝납니다.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _resume(WidgetTester tester) async {
  // 실제 시계 영역에서 보내야 DB·통신 await 사슬이 끝까지 돕니다.
  await tester.runAsync(() async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
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
    await _drain(tester);
    await _resume(tester);
    expect(server.bodies, isEmpty);

    device.value = 'America/Los_Angeles';
    await _resume(tester);
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
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    // 앱에서는 todayProvider가 구독하고 있으므로 같은 조건을 만듭니다.
    container.listen(profileTimezoneProvider, (_, _) {});
    await _drain(tester);
    expect(container.read(profileTimezoneProvider), 'Asia/Seoul');
    device.value = 'America/Los_Angeles';
    await _resume(tester);
    await _drain(tester);
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
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
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
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(server.bodies, [
      {'currentTimezone': 'Asia/Tokyo'},
    ]);
  });
}
