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

/// 앱 전체를 fake 모드의 [scenario]로 띄우고 진입 계산이 끝날 때까지 기다립니다.
///
/// 로컬 DB는 메모리, 보안 저장소는 메모리 대역, 앱 버전은 1.0.0, 로케일은 ko로 바꿉니다.
/// 대역 서버가 asset을 실제 I/O로 읽으므로 기다리는 동안 `runAsync`로 시계를 풀어 줍니다.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required String scenario,
  List<Override> overrides = const [],
}) async {
  final container = (await tester.runAsync(() async {
    // 번들의 asset 목록 Future를 진짜 시계 영역에서 만들어 둡니다. 테스트마다 다른 가짜 시계에서
    // 처음 만들어지면 다음 테스트가 그 Future를 기다리다 멈춥니다.
    await AssetManifest.loadFromAssetBundle(rootBundle);
    final bootstrapped = await bootstrap(
      mode: ApiMode.fake,
      scenarioId: scenario,
      installErrorHandlers: false,
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final database = AppDatabase.forExecutor(NativeDatabase.memory());
          ref.onDispose(database.close);
          return database;
        }),
        secureStoreProvider.overrideWithValue(MemorySecureStore()),
        localeProvider.overrideWithValue(const Locale('ko')),
        appVersionProvider.overrideWith((ref) => Version(1, 0, 0)),
        ...overrides,
      ],
    );
    return bootstrapped;
  }))!;
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyungliApp()),
  );
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (!container.read(entryStateProvider).isLoading) {
      break;
    }
  }
  await tester.pumpAndSettle();
  return container;
}
