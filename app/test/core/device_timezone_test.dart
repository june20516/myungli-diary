import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fake 모드 컨테이너의 기기 시간대는 시나리오 timezone이다', () async {
    final container = await bootstrapForTest('new-user');
    addTearDown(container.dispose);
    expect(
      await container.read(deviceTimezoneProvider).current(),
      'Asia/Seoul',
    );
  });

  test('FakeDeviceTimezone은 준 값을 돌려준다', () async {
    expect(
      await const FakeDeviceTimezone('America/New_York').current(),
      'America/New_York',
    );
  });

  test('nonceGeneratorProvider는 계약 길이의 nonce를 만든다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(nonceGeneratorProvider), isA<NonceGenerator>());
  });

  test('FakeStoreLauncher는 연 횟수를 센다', () async {
    final launcher = FakeStoreLauncher();
    await launcher.openStore();
    await launcher.openStore();
    expect(launcher.opened, 2);
    expect(
      ProviderContainer().read(storeLauncherProvider),
      isA<StoreLauncher>(),
    );
  });
}
