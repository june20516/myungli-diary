import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/platform/device_timezone.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fake 모드 컨테이너의 기기 시간대는 시나리오 timezone이고 스토어는 대역이다', () async {
    final container = await bootstrapForTest('new-user');
    addTearDown(container.dispose);
    expect(
      await container.read(deviceTimezoneProvider).current(),
      'Asia/Seoul',
    );
    expect(container.read(storeLauncherProvider), isA<FakeStoreLauncher>());
  });

  test('기본값은 대역이다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(deviceTimezoneProvider), isA<FakeDeviceTimezone>());
    expect(container.read(storeLauncherProvider), isA<FakeStoreLauncher>());
  });

  test('http 모드 부팅은 실제 adapter를 끼운다', () {
    final container = ProviderContainer(
      overrides: realPlatformOverrides(ApiMode.http),
    );
    addTearDown(container.dispose);
    expect(
      container.read(deviceTimezoneProvider),
      isA<FlutterDeviceTimezone>(),
    );
    expect(container.read(storeLauncherProvider), isA<UrlStoreLauncher>());
  });

  test('fake 모드에는 실제 adapter를 끼우지 않는다', () {
    expect(realPlatformOverrides(ApiMode.fake), isEmpty);
  });

  test('FakeDeviceTimezone은 준 값을 돌려준다', () async {
    expect(
      await const FakeDeviceTimezone('America/New_York').current(),
      'America/New_York',
    );
  });

  test('nonceGeneratorProvider는 32자 base64url nonce를 만든다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final nonce = container.read(nonceGeneratorProvider).generate();
    expect(nonce, hasLength(32));
    expect(nonce, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
  });

  test('FakeStoreLauncher는 연 횟수를 센다', () async {
    final launcher = FakeStoreLauncher();
    await launcher.openStore();
    await launcher.openStore();
    expect(launcher.opened, 2);
  });
}
