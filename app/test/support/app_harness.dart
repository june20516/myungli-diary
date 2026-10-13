import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:pub_semver/pub_semver.dart';

/// 테스트용으로 바꾸는 provider: 메모리 DB, 메모리 보안 저장소, 앱 버전 1.0.0, 로케일 ko.
///
/// [database]를 주면 그 실행기로 DB를 엽니다(여러 컨테이너가 같은 파일을 공유할 때).
List<Override> testOverrides({QueryExecutor Function()? database}) => [
  appDatabaseProvider.overrideWith((ref) {
    final db = AppDatabase.forExecutor(
      database?.call() ?? NativeDatabase.memory(),
    );
    ref.onDispose(db.close);
    return db;
  }),
  secureStoreProvider.overrideWithValue(MemorySecureStore()),
  localeProvider.overrideWithValue(const Locale('ko')),
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
}) async {
  await AssetManifest.loadFromAssetBundle(rootBundle);
  final container = await bootstrap(
    mode: ApiMode.fake,
    scenarioId: scenario,
    installErrorHandlers: false,
    overrides: [
      ...testOverrides(database: database),
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
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('진입 계산이 끝나지 않음');
}

/// 앱 전체를 fake 모드의 [scenario]로 띄우고 진입 계산이 끝날 때까지 기다립니다.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required String scenario,
  List<Override> overrides = const [],
}) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(scenario, overrides: overrides),
  ))!;
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyungliApp()),
  );
  await settleEntry(tester, container);
  return container;
}
