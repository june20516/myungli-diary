import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';

import '../../support/profile_sync_harness.dart';

void main() {
  testWidgets('사본과 기기 시간대가 다르면 PATCH 본문에 currentTimezone만 보낸다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'America/Los_Angeles',
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, [
      {'currentTimezone': 'America/Los_Angeles'},
    ]);
    // 응답이 사본이 되어 다시 부르면 보내지 않습니다.
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, hasLength(1));
  });

  testWidgets('같으면 보내지 않는다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Seoul',
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, isEmpty);
  });

  testWidgets('UTC offset이 같아도 IANA 이름이 다르면 보낸다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, [
      {'currentTimezone': 'Asia/Tokyo'},
    ]);
  });

  testWidgets('503이어도 예외가 나오지 않고 다음에 다시 보낸다', (tester) async {
    final (container, server, reporter) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      failures: 1,
    );
    final sync = container.read(timezoneSyncProvider);
    await tester.runAsync(sync.syncIfChanged);
    expect(server.bodies, hasLength(1));
    expect(reporter.errors.single.status, 503);
    await tester.runAsync(sync.syncIfChanged);
    expect(server.bodies, hasLength(2));
    expect(reporter.errors, hasLength(1));
  });

  testWidgets('ready인데 사본이 없으면 기기 시간대를 한 번 보내고 응답을 사본으로 삼는다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      seed: false,
    );
    final sync = container.read(timezoneSyncProvider);
    await tester.runAsync(sync.syncIfChanged);
    expect(server.bodies, [
      {'currentTimezone': 'Asia/Tokyo'},
    ]);
    final cached = await tester.runAsync(
      container.read(profileRepositoryProvider).cached,
    );
    expect(cached?.currentTimezone, 'Asia/Tokyo');
    await tester.runAsync(sync.syncIfChanged);
    expect(server.bodies, hasLength(1));
  });

  testWidgets('사본이 없을 때 보내기가 실패하면 다음 기회에 다시 보낸다', (tester) async {
    final (container, server, reporter) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      seed: false,
      failures: 1,
    );
    final sync = container.read(timezoneSyncProvider);
    await tester.runAsync(sync.syncIfChanged);
    expect(reporter.errors.single.status, 503);
    await tester.runAsync(sync.syncIfChanged);
    expect(server.bodies, hasLength(2));
  });

  testWidgets('진입이 ready가 아니면 보내지 않는다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      overrides: [entryProvider.overrideWithValue(EntryState.signedOut)],
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, isEmpty);
  });
}
