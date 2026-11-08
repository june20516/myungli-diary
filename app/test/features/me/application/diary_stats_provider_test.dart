import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/model/diary_edit_target.dart';
import 'package:myungli_diary/features/me/application/diary_stats_provider.dart';

final _today = CalendarDate(2026, 10, 13);

final class _Offline extends Interceptor {
  bool offline = false;

  /// 받은 요청 수.
  int requests = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests++;
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: '오프라인'),
      );
      return;
    }
    handler.next(options);
  }
}

Future<(ProviderContainer, FakeServerInterceptor, _Offline)> _harness() async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == 'member');
  final server = FakeServerInterceptor(scenario: scenario, bundle: rootBundle);
  final network = _Offline();
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(
        DefaultApi(
          Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
            ..interceptors.addAll([network, server]),
        ),
      ),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      appDatabaseProvider.overrideWithValue(database),
      currentAccountIdProvider.overrideWithValue('a'),
      todayProvider.overrideWithValue(_today),
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return (container, server, network);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('diaryStatsProvider', () {
    test('저장소 일기에서 센 집계를 받습니다(날의 성격 네 값 모두)', () async {
      final (container, _, _) = await _harness();
      final subscription = container.listen(diaryStatsProvider, (_, _) {});
      addTearDown(subscription.close);
      final stats = await container.read(diaryStatsProvider.future);
      expect(stats.entryCount, greaterThan(0));
      expect(stats.dayKinds, hasLength(4));
    });

    test('캐시가 없어 구독이 끊긴 뒤 다시 읽으면 다시 묻습니다(autoDispose)', () async {
      final (container, server, _) = await _harness();
      final first = container.listen(diaryStatsProvider, (_, _) {});
      await container.read(diaryStatsProvider.future);
      first.close();
      await Future<void>.delayed(Duration.zero);
      final second = container.listen(diaryStatsProvider, (_, _) {});
      addTearDown(second.close);
      await container.read(diaryStatsProvider.future);
      expect(server.callCountOf('getDiaryStats'), 2);
    });

    test('일기를 저장하면 집계를 다시 읽고 편수가 하나 늘어납니다', () async {
      final (container, server, _) = await _harness();
      final subscription = container.listen(diaryStatsProvider, (_, _) {});
      addTearDown(subscription.close);
      final before = await container.read(diaryStatsProvider.future);
      final target = DiaryEditTarget.newOn(_today);
      final edit = container.listen(diaryEditProvider(target), (_, _) {});
      addTearDown(edit.close);
      await container.read(diaryEditProvider(target).future);
      await container.read(diaryEditProvider(target).notifier).save('새로 쓴 글');
      final after = await container.read(diaryStatsProvider.future);
      expect(server.callCountOf('getDiaryStats'), 2);
      expect(after.entryCount, before.entryCount + 1);
    });

    test('본문만 고친 저장은 집계를 다시 읽지 않습니다', () async {
      final (container, server, _) = await _harness();
      final subscription = container.listen(diaryStatsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(diaryStatsProvider.future);
      final repository = container.read(diaryRepositoryProvider);
      final summary = (await repository.diariesOn(CalendarDate(2026, 10, 12)))
          .first;
      final target = DiaryEditTarget.existing(summary.id);
      final edit = container.listen(diaryEditProvider(target), (_, _) {});
      addTearDown(edit.close);
      await container.read(diaryEditProvider(target).future);
      await container.read(diaryEditProvider(target).notifier).save('고친 글');
      await Future<void>.delayed(Duration.zero);
      expect(server.callCountOf('getDiaryStats'), 1);
    });

    test('일기를 지우면 집계를 다시 읽고 편수가 하나 줄어듭니다', () async {
      final (container, server, _) = await _harness();
      final subscription = container.listen(diaryStatsProvider, (_, _) {});
      addTearDown(subscription.close);
      final before = await container.read(diaryStatsProvider.future);
      final repository = container.read(diaryRepositoryProvider);
      final summary = (await repository.diariesOn(CalendarDate(2026, 10, 12)))
          .first;
      final diary = (await repository.find(summary.id))!;
      await container.read(diaryDeleterProvider.notifier).delete(diary);
      final after = await container.read(diaryStatsProvider.future);
      expect(server.callCountOf('getDiaryStats'), 2);
      expect(after.entryCount, before.entryCount - 1);
    });

    test('연결이 끊기면 AppError(오프라인)로 실패하고 자동 재시도하지 않습니다', () async {
      final (container, _, network) = await _harness();
      network.offline = true;
      final subscription = container.listen(diaryStatsProvider, (_, _) {});
      addTearDown(subscription.close);
      await expectLater(
        container.read(diaryStatsProvider.future),
        throwsA(isA<OfflineError>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(network.requests, 1);
    });
  });
}
