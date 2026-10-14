import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/core/storage/installation_id.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('처음 읽으면 UUID v4를 만들고, 같은 DB로 다시 만든 컨테이너도 같은 값이다', () async {
    final database = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    ProviderContainer containerOver() => ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );

    final first = containerOver();
    final id = await first.read(installationIdProvider.future);
    first.dispose();
    expect(id, matches(uuidV4));

    final second = containerOver();
    addTearDown(second.dispose);
    expect(await second.read(installationIdProvider.future), id);
  });

  test('저장값이 UUID v4 형식이 아니면 새로 만들어 저장한다', () async {
    final database = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DeviceFlagsStore(database);
    await store.writeString(installationIdKey, value: 'broken');
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final id = await container.read(installationIdProvider.future);

    expect(id, isNot('broken'));
    expect(id, matches(RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-4')));
    expect(await store.readString(installationIdKey), id);
  });
}
