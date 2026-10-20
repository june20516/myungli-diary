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
import 'package:myungli_diary/features/diary/application/diary_pages.dart';

final _today = CalendarDate(2026, 10, 13);

/// [offline]이면 요청을 연결 오류로 끊고, 아니면 fake 서버(member)로 보냅니다.
final class _Network extends Interceptor {
  bool offline = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: '오프라인'),
      );
      return;
    }
    handler.next(options);
  }
}

final class _Harness {
  new(this.container, this.server, this.network);

  final ProviderContainer container;
  final FakeServerInterceptor server;
  final _Network network;

  int calls(String operationId) => server.callCountOf(operationId);
}

Future<_Harness> _harness({int pageSize = 2}) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == 'member');
  final server = FakeServerInterceptor(scenario: scenario, bundle: rootBundle);
  final network = _Network();
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
      diaryPageSizeProvider.overrideWithValue(pageSize),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return _Harness(container, server, network);
}

Future<DiaryPagesView> _pages(_Harness h, [String? tag]) async {
  final subscription = h.container.listen(diaryPagesProvider(tag), (_, _) {});
  addTearDown(subscription.close);
  return await h.container.read(diaryPagesProvider(tag).future);
}

List<String> _dates(DiaryPagesView view) => [
  for (final item in view.items) item.date,
];

Future<DiaryEditState> _edit(_Harness h, CalendarDate date) async {
  final subscription = h.container.listen(diaryEditProvider(date), (_, _) {});
  addTearDown(subscription.close);
  return await h.container.read(diaryEditProvider(date).future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('diaryPagesProvider', () {
    test('첫 쪽을 받고 loadMore가 다음 쪽을 붙이며 마지막 쪽 뒤에는 묻지 않습니다', () async {
      final h = await _harness();
      expect(_dates(await _pages(h)), ['2026-10-12', '2026-10-08']);
      final notifier = h.container.read(diaryPagesProvider(null).notifier);
      await notifier.loadMore();
      final view = h.container.read(diaryPagesProvider(null)).value!;
      expect(_dates(view), [
        '2026-10-12',
        '2026-10-08',
        '2026-10-05',
        '2026-10-02',
      ]);
      expect(view.hasMore, isFalse);
      final before = h.calls('listDiaries');
      await notifier.loadMore();
      expect(h.calls('listDiaries'), before);
    });

    test('loadMore를 겹쳐 불러도 같은 cursor는 한 번만 묻습니다', () async {
      final h = await _harness();
      await _pages(h);
      final notifier = h.container.read(diaryPagesProvider(null).notifier);
      final before = h.calls('listDiaries');
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);
      expect(h.calls('listDiaries'), before + 1);
    });

    test('다음 쪽이 실패하면 받아 둔 쪽은 그대로이고 moreError가 남습니다', () async {
      final h = await _harness();
      await _pages(h);
      h.network.offline = true;
      await h.container.read(diaryPagesProvider(null).notifier).loadMore();
      final view = h.container.read(diaryPagesProvider(null)).value!;
      expect(_dates(view), ['2026-10-12', '2026-10-08']);
      expect(view.moreError, isA<OfflineError>());
      expect(view.hasMore, isTrue);
    });

    test('오프라인에서 다시 받기가 실패해도 받아 둔 목록을 들고 있습니다', () async {
      final h = await _harness();
      await _pages(h);
      h.network.offline = true;
      h.container.invalidate(diaryPagesProvider(null));
      await expectLater(
        h.container.read(diaryPagesProvider(null).future),
        throwsA(isA<OfflineError>()),
      );
      final state = h.container.read(diaryPagesProvider(null));
      expect(state.error, isA<OfflineError>());
      expect(_dates(heldDiaryPagesOf(state)!), ['2026-10-12', '2026-10-08']);
    });

    test('받아 둔 것이 없는데 오프라인이면 오류입니다', () async {
      final h = await _harness();
      h.network.offline = true;
      await expectLater(_pages(h), throwsA(isA<OfflineError>()));
      expect(
        heldDiaryPagesOf(h.container.read(diaryPagesProvider(null))),
        isNull,
      );
    });

    test('태그 목록은 그 태그 일기만입니다', () async {
      final h = await _harness();
      expect(_dates(await _pages(h, 'clash')), ['2026-10-02']);
    });

    test('로그아웃하면 받아 둔 목록을 버립니다', () async {
      final h = await _harness();
      await _pages(h);
      h.network.offline = true;
      await h.container.read(tokenStoreProvider).signOut();
      await Future<void>.delayed(Duration.zero);
      expect(
        heldDiaryPagesOf(h.container.read(diaryPagesProvider(null))),
        isNull,
      );
    });
  });

  group('diaryEditProvider', () {
    test('새 날짜는 빈 본문, 그날 daily의 가이드 질문, 상태 없음입니다', () async {
      final h = await _harness();
      final state = await _edit(h, _today);
      expect(state.initialBody, '');
      expect(state.existing, isNull);
      expect(state.question, isNotNull);
      expect(state.status, isNull);
      expect(state.fromDraft, isFalse);
    });

    test('저장된 일기는 그 본문·저장됨 상태이고 daily를 묻지 않습니다', () async {
      final h = await _harness();
      final state = await _edit(h, CalendarDate(2026, 10, 12));
      expect(state.initialBody, startsWith('오랜만에'));
      expect(state.status, DiaryDraftStatus.saved);
      expect(h.calls('getDaily'), 0);
    });

    test('초안이 있으면 저장된 본문보다 앞서고 draft 상태입니다', () async {
      final h = await _harness();
      await h.container
          .read(diaryDraftStoreProvider)
          .write(CalendarDate(2026, 10, 12), '고치던 글');
      final state = await _edit(h, CalendarDate(2026, 10, 12));
      expect(state.initialBody, '고치던 글');
      expect(state.fromDraft, isTrue);
      expect(state.status, DiaryDraftStatus.local);
    });

    test('edit 뒤 diaryDraftDelay가 지나면 초안이 남고 local 상태입니다', () async {
      final h = await _harness();
      await _edit(h, _today);
      final notifier = h.container.read(diaryEditProvider(_today).notifier)
        ..edit('쓰는 중');
      final drafts = h.container.read(diaryDraftStoreProvider);
      expect(await drafts.read(_today), isNull, reason: '아직 기다리는 중');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      expect(await drafts.read(_today), '쓰는 중');
      expect(
        h.container.read(diaryEditProvider(_today)).value!.status,
        DiaryDraftStatus.local,
      );
      notifier.edit('   ');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      expect(await drafts.read(_today), isNull);
    });

    test('저장을 겹쳐 눌러도 putDiary는 한 번이고, 성공하면 초안을 지우고 목록이 새로 받힙니다', () async {
      final h = await _harness(pageSize: 30);
      await _pages(h);
      await _edit(h, _today);
      final drafts = h.container.read(diaryDraftStoreProvider);
      await drafts.write(_today, '오늘 일기');
      final notifier = h.container.read(diaryEditProvider(_today).notifier);
      final results = await Future.wait([
        notifier.save('오늘 일기'),
        notifier.save('오늘 일기'),
      ]);
      expect(results.whereType<Object>(), hasLength(1));
      expect(h.calls('putDiary'), 1);
      expect(await drafts.read(_today), isNull);
      final state = h.container.read(diaryEditProvider(_today)).value!;
      expect(state.status, DiaryDraftStatus.saved);
      expect(state.existing!.body, '오늘 일기');
      expect(_dates(await _pages(h)).first, '2026-10-13');
    });

    test('오프라인 저장은 OfflineError이고 초안이 남으며 offline입니다', () async {
      final h = await _harness();
      await _edit(h, _today);
      h.network.offline = true;
      await expectLater(
        h.container.read(diaryEditProvider(_today).notifier).save('끊긴 글'),
        throwsA(isA<OfflineError>()),
      );
      expect(
        await h.container.read(diaryDraftStoreProvider).read(_today),
        '끊긴 글',
      );
      final state = h.container.read(diaryEditProvider(_today)).value!;
      expect(
        (state.offline, state.saving, state.status),
        (true, false, DiaryDraftStatus.local),
      );
    });

    test('빈 본문은 저장하지 않습니다', () async {
      final h = await _harness();
      await _edit(h, _today);
      expect(
        await h.container.read(diaryEditProvider(_today).notifier).save('  \n'),
        isNull,
      );
      expect(h.calls('putDiary'), 0);
    });

    test('오프라인으로 열면 초안으로 쓸 수 있고 offline입니다', () async {
      final h = await _harness();
      await h.container.read(diaryDraftStoreProvider).write(_today, '초안');
      h.network.offline = true;
      final state = await _edit(h, _today);
      expect(state.initialBody, '초안');
      expect(state.offline, isTrue);
      expect(state.question, isNull);
    });
  });

  group('diaryDeleterProvider', () {
    test('지우면 그날 일기가 없어지고 초안도 지웁니다', () async {
      final h = await _harness();
      final date = CalendarDate(2026, 10, 12);
      await h.container.read(diaryDraftStoreProvider).write(date, '초안');
      expect(
        await h.container.read(diaryDeleterProvider.notifier).delete(date),
        isTrue,
      );
      expect(await h.container.read(diaryOnProvider(date).future), isNull);
      expect(
        await h.container.read(diaryDraftStoreProvider).read(date),
        isNull,
      );
    });

    test('이미 없으면 diary.not_found ProblemError입니다', () async {
      final h = await _harness();
      await expectLater(
        h.container.read(diaryDeleterProvider.notifier).delete(_today),
        throwsA(
          isA<ProblemError>().having((e) => e.code, 'code', 'diary.not_found'),
        ),
      );
      expect(h.container.read(diaryDeleterProvider), isFalse);
    });
  });
}
