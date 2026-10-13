import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/dev/scenario_picker.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('개발 메뉴 재시작은 이전 시나리오의 기기 플래그와 캐시를 남기지 않습니다', (tester) async {
    final directory = Directory.systemTemp.createTempSync('dev_restart');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/db.sqlite');
    QueryExecutor open() => NativeDatabase(file);

    final first = (await tester.runAsync(
      () => bootstrapForTest('member', database: open),
    ))!;
    await tester.pumpWidget(
      DevHost(
        initial: first,
        createContainer: (scenarioId) =>
            bootstrapForTest(scenarioId, database: open),
      ),
    );
    await settleEntry(tester, first);
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    // member 시나리오의 흔적을 남깁니다.
    await tester.runAsync(() async {
      await first
          .read(cacheStoreProvider)
          .write(
            CacheKind.calendar,
            'k',
            '{}',
            access: EvidenceAccess.unlocked,
          );
      await first
          .read(deviceFlagsStoreProvider)
          .writeBool('dev.flag', value: true);
    });

    final scope = DevRestartScope.maybeOf(
      tester.element(find.byKey(const ValueKey(ScreenIds.today))),
    )!;
    await tester.runAsync(() => scope.restart('new-user'));
    await tester.pump();
    // 새 컨테이너의 진입 계산을 기다립니다.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(const ValueKey(ScreenIds.welcome)).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
    final probe = AppDatabase.forExecutor(open());
    addTearDown(probe.close);
    final leftovers = await tester.runAsync(() async {
      return (
        cache: await CacheStore(
          probe,
          accountId: '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10',
        ).read(CacheKind.calendar, 'k'),
        flag: await DeviceFlagsStore(probe).readBool('dev.flag'),
      );
    });
    expect(leftovers!.cache, isNull);
    expect(leftovers.flag, isFalse);
  });

  test('재시작 정리는 만든 적 없는 DB를 열지 않고, 연 DB는 닫습니다', () async {
    var created = 0;
    ProviderContainer containerWithCountingDatabase() => ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          created++;
          return AppDatabase.forExecutor(NativeDatabase.memory());
        }),
      ],
    );

    await disposeClosingDatabase(containerWithCountingDatabase());
    expect(created, 0);

    final used = containerWithCountingDatabase();
    final database = used.read(appDatabaseProvider);
    await database.customSelect('SELECT 1').get();
    await disposeClosingDatabase(used);
    expect(created, 1);
    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsA(anything),
      reason: '닫힌 DB',
    );
  });
}
