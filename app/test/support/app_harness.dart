import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:pub_semver/pub_semver.dart';

/// 테스트용으로 바꾸는 provider: 메모리 DB, 메모리 보안 저장소, 앱 버전 1.0.0, 로케일 ko.
///
/// [database]를 주면 그 실행기로 DB를 엽니다(여러 컨테이너가 같은 파일을 공유할 때).
///
/// [locale]이 null이면 로케일을 덮지 않아 시나리오의 `locale`이 쓰입니다.
List<Override> testOverrides({
  QueryExecutor Function()? database,
  Locale? locale = const Locale('ko'),
}) => [
  appDatabaseProvider.overrideWith((ref) {
    final db = AppDatabase.forExecutor(
      database?.call() ?? NativeDatabase.memory(),
    );
    ref.onDispose(db.close);
    return db;
  }),
  secureStoreProvider.overrideWithValue(MemorySecureStore()),
  if (locale != null) localeProvider.overrideWithValue(locale),
  appVersionProvider.overrideWith((ref) => Version(1, 0, 0)),
];

/// fake 모드 [scenario]의 컨테이너를 [testOverrides]로 만듭니다. 진짜 시계 영역에서 불러야 합니다.
///
/// 번들의 asset 목록 Future를 진짜 시계 영역에서 먼저 만들어 둡니다. 테스트마다 다른
/// 가짜 시계에서 처음 만들어지면 다음 테스트가 그 Future를 기다리다 멈춥니다.
Future<ProviderContainer> bootstrapForTest(
  String scenario, {
  List<Override> overrides = const [],
  QueryExecutor Function()? database,
  Locale? locale = const Locale('ko'),
}) async {
  await AssetManifest.loadFromAssetBundle(rootBundle);
  final container = await bootstrap(
    mode: ApiMode.fake,
    scenarioId: scenario,
    installErrorHandlers: false,
    // 로케일은 bootstrap이 시나리오의 `locale`과 함께 정합니다(둘 다 덮으면 override가 겹침).
    deviceLocale: locale,
    overrides: [
      ...testOverrides(database: database, locale: null),
      ...overrides,
    ],
  );
  return container;
}

/// 진입 계산이 끝날 때까지 기다립니다. 대역 서버가 asset을 실제 I/O로 읽으므로
/// `runAsync`로 시계를 풀어 줍니다. 끝나지 않으면 테스트를 실패시킵니다.
Future<void> settleEntry(
  WidgetTester tester,
  ProviderContainer container,
) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (!container.read(entryStateProvider).isLoading) {
      await settleWithIo(tester);
      // 진입이 ready가 되면 앱 셸이 기기 시간대를 맞추는 요청을 보냅니다. 끝나게 둡니다.
      await settleTimezoneSync(tester, container);
      await settleWithIo(tester);
      return;
    }
  }
  fail('진입 계산이 끝나지 않음');
}

/// 실제 I/O와 프레임을 번갈아 돌며 예약된 프레임이 없어질 때까지 기다립니다.
///
/// 도착한 화면이 server 응답을 기다리는 동안 skeleton이 숨 쉬면 `pumpAndSettle`이 끝나지
/// 않습니다(대역 서버는 asset을 실제 I/O로 읽음). 응답이 오면 움직임이 멎으므로 그때 끝냅니다.
/// [maxRounds]가 지나도 움직이면(응답을 일부러 붙잡은 테스트) 실패하지 않고 그대로 돌아갑니다.
Future<void> settleWithIo(WidgetTester tester, {int maxRounds = 100}) async {
  for (var i = 0; i < maxRounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (!tester.binding.hasScheduledFrame) {
      return;
    }
  }
}

/// 진행 중인 기기 시간대 동기화([TimezoneSync.idle])가 끝날 때까지 기다립니다.
///
/// 진입이 `ready`가 아니면 동기화가 없으므로 바로 끝납니다. 끝나지 않으면 테스트를 실패시킵니다.
/// 가짜 시계 영역에서 시작한 await 사슬은 실제 I/O와 microtask 처리를 번갈아 거쳐야 하므로
/// 둘을 번갈아 돌며 완료를 확인합니다.
Future<void> settleTimezoneSync(
  WidgetTester tester,
  ProviderContainer container,
) async {
  if (container.read(entryProvider) != EntryState.ready) {
    return;
  }
  var done = false;
  unawaited(
    container.read(timezoneSyncProvider).idle.whenComplete(() => done = true),
  );
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (done) {
      await tester.pump();
      return;
    }
  }
  fail('기기 시간대 동기화가 끝나지 않음');
}

/// 앱 전체를 fake 모드의 [scenario]로 띄우고 진입 계산이 끝날 때까지 기다립니다.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required String scenario,
  List<Override> overrides = const [],
  Locale? locale = const Locale('ko'),
}) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(scenario, overrides: overrides, locale: locale),
  ))!;
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyungliApp()),
  );
  await settleEntry(tester, container);
  return container;
}
