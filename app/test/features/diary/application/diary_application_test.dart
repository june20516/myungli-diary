import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
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
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/model/diary_draft_target.dart';
import 'package:myungli_diary/features/diary/model/diary_edit_target.dart';

final _today = CalendarDate(2026, 10, 13);

/// [offline]이면 요청을 연결 오류로 끊고, 아니면 fake 서버(member)로 보냅니다.
final class _Network extends Interceptor {
  bool offline = false;

  /// 다음 `createDiary` 요청 하나를 시간 초과로 끊습니다.
  bool timeoutNextCreate = false;

  /// 있으면 `createDiary` 요청을 이 completer가 끝날 때까지 붙잡습니다.
  Completer<void>? holdCreate;

  /// 있으면 `getDaily` 요청을 이 completer가 끝날 때까지 붙잡은 뒤 예상 못한 오류로 끊습니다.
  Completer<void>? holdDailyThenFail;

  /// `createDiary`가 받은 `Idempotency-Key`.
  final createKeys = <String?>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final holdDaily = holdDailyThenFail;
    if (holdDaily != null && options.path.contains('/daily')) {
      unawaited(
        holdDaily.future.then(
          (_) => handler.reject(
            DioException(
              requestOptions: options,
              error: StateError('예상 못한 오류'),
            ),
          ),
        ),
      );
      return;
    }
    if (options.method == 'POST' && options.path == '/v1/diaries') {
      createKeys.add(options.headers['Idempotency-Key'] as String?);
      final hold = holdCreate;
      if (hold != null) {
        unawaited(hold.future.then((_) => handler.next(options)));
        return;
      }
      if (timeoutNextCreate) {
        timeoutNextCreate = false;
        handler.reject(
          DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: options,
          ),
        );
        return;
      }
    }
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: '오프라인'),
      );
      return;
    }
    handler.next(options);
  }
}

/// 있으면 초안 쓰기(insert)를 이 completer가 끝날 때까지 붙잡는 DB 가로채기.
final class _DraftWriteHold extends QueryInterceptor {
  Completer<void>? hold;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await hold?.future;
    return await super.runInsert(executor, statement, args);
  }
}

final class _Harness {
  new(this.container, this.server, this.network, this.draftWrites);

  final ProviderContainer container;
  final FakeServerInterceptor server;
  final _Network network;
  final _DraftWriteHold draftWrites;

  int calls(String operationId) => server.callCountOf(operationId);
}

Future<_Harness> _harness({
  int pageSize = 2,
  String scenarioId = 'member',
}) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == scenarioId);
  final server = FakeServerInterceptor(scenario: scenario, bundle: rootBundle);
  final network = _Network();
  final draftWrites = _DraftWriteHold();
  final database = AppDatabase.forExecutor(
    NativeDatabase.memory().interceptWith(draftWrites),
  );
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
  return _Harness(container, server, network, draftWrites);
}

Future<DiaryPagesView> _pages(_Harness h, [String? tag]) async {
  final subscription = h.container.listen(diaryPagesProvider(tag), (_, _) {});
  addTearDown(subscription.close);
  return await h.container.read(diaryPagesProvider(tag).future);
}

List<String> _dates(DiaryPagesView view) => [
  for (final item in view.items) item.date,
];

Future<DiaryEditState> _edit(_Harness h, DiaryEditTarget target) async {
  final subscription = h.container.listen(diaryEditProvider(target), (_, _) {});
  addTearDown(subscription.close);
  return await h.container.read(diaryEditProvider(target).future);
}

/// [date]에 이미 있는 첫 일기의 id.
Future<String> _idOn(_Harness h, CalendarDate date) async =>
    (await h.container.read(diaryRepositoryProvider).diariesOn(date)).first.id;

final _newToday = DiaryEditTarget.newOn(_today);
final _draftToday = DiaryDraftTarget.newOn(_today);

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
    test('새 일기는 빈 본문, 그날 daily의 가이드 질문, 상태 없음입니다', () async {
      final h = await _harness();
      final state = await _edit(h, _newToday);
      expect(state.date, _today);
      expect(state.initialBody, '');
      expect(state.existing, isNull);
      expect(state.question, isNotNull);
      expect(state.status, isNull);
      expect(state.fromDraft, isFalse);
    });

    test('고치기는 그 일기의 본문·날짜·저장됨 상태이고 daily를 묻지 않습니다', () async {
      final h = await _harness();
      final id = await _idOn(h, CalendarDate(2026, 10, 12));
      final state = await _edit(h, DiaryEditTarget.existing(id));
      expect(state.date, CalendarDate(2026, 10, 12));
      expect(state.existing!.id, id);
      expect(state.initialBody, startsWith('오랜만에'));
      expect(state.status, DiaryDraftStatus.saved);
      expect(h.calls('getDaily'), 0);
    });

    test('없는 일기를 고치려 열면 diary.not_found ProblemError입니다', () async {
      final h = await _harness();
      await expectLater(
        _edit(
          h,
          const DiaryEditTarget.existing(
            '00000000-0000-4000-8000-000000000000',
          ),
        ),
        throwsA(
          isA<ProblemError>().having((e) => e.code, 'code', 'diary.not_found'),
        ),
      );
    });

    test('고치기를 열면 그 일기 초안이 저장된 본문보다 앞섭니다', () async {
      final h = await _harness();
      final date = CalendarDate(2026, 10, 12);
      final id = await _idOn(h, date);
      await h.container
          .read(diaryDraftStoreProvider)
          .write(DiaryDraftTarget.existing(date: date, id: id), '고치던 글');
      final state = await _edit(h, DiaryEditTarget.existing(id));
      expect(state.initialBody, '고치던 글');
      expect(state.fromDraft, isTrue);
      expect(state.status, DiaryDraftStatus.local);
    });

    test('edit 뒤 diaryDraftDelay가 지나면 초안이 남고 local 상태입니다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier)
        ..edit('쓰는 중');
      final drafts = h.container.read(diaryDraftStoreProvider);
      expect(await drafts.read(_draftToday), isNull, reason: '아직 기다리는 중');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      expect(await drafts.read(_draftToday), '쓰는 중');
      expect(
        h.container.read(diaryEditProvider(_newToday)).value!.status,
        DiaryDraftStatus.local,
      );
      notifier.edit('   ');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      expect(await drafts.read(_draftToday), isNull);
    });

    test('새 일기 저장은 create이고 성공하면 그날 새 일기 초안을 지운다', () async {
      final h = await _harness(pageSize: 30);
      await _pages(h);
      await _edit(h, _newToday);
      final drafts = h.container.read(diaryDraftStoreProvider);
      await drafts.write(_draftToday, '오늘 일기');
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      final results = await Future.wait([
        notifier.save('오늘 일기'),
        notifier.save('오늘 일기'),
      ]);
      expect(results.whereType<Object>(), hasLength(1), reason: '겹친 저장은 하나');
      expect(h.calls('createDiary'), 1);
      expect(h.calls('updateDiary'), 0);
      expect(await drafts.read(_draftToday), isNull);
      final state = h.container.read(diaryEditProvider(_newToday)).value!;
      expect(state.status, DiaryDraftStatus.saved);
      expect(state.existing!.body, '오늘 일기');
      expect(_dates(await _pages(h)).first, '2026-10-13');
    });

    test('새 일기를 저장한 같은 화면에서 다시 저장하면 update입니다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      final created = (await notifier.save('처음'))!;
      final updated = (await notifier.save('고침'))!;
      expect(updated.id, created.id);
      expect(updated.body, '고침');
      expect(h.calls('createDiary'), 1);
      expect(h.calls('updateDiary'), 1);
    });

    test(
      '새 일기 저장이 TimeoutError로 실패한 뒤 다시 저장하면 같은 Idempotency-Key를 보낸다',
      () async {
        final h = await _harness();
        await _edit(h, _newToday);
        final notifier = h.container.read(
          diaryEditProvider(_newToday).notifier,
        );
        h.network.timeoutNextCreate = true;
        await expectLater(notifier.save('느린 글'), throwsA(isA<TimeoutError>()));
        expect(await notifier.save('느린 글'), isNotNull);
        expect(h.network.createKeys, hasLength(2));
        expect(h.network.createKeys.first, isNotNull);
        expect(h.network.createKeys.last, h.network.createKeys.first);
      },
    );

    test('새 일기에서 본문을 바꿔 다시 저장하면 새 Idempotency-Key를 보낸다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      h.network.timeoutNextCreate = true;
      await expectLater(notifier.save('처음 글'), throwsA(isA<TimeoutError>()));
      h.network.timeoutNextCreate = true;
      await expectLater(notifier.save('고친 글'), throwsA(isA<TimeoutError>()));
      expect(h.network.createKeys, hasLength(2));
      expect(h.network.createKeys.last, isNot(h.network.createKeys.first));
    });

    test('저장 중에 들어온 입력은 저장 뒤 그 일기 초안으로 남는다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      final drafts = h.container.read(diaryDraftStoreProvider);
      h.network.holdCreate = Completer<void>();
      final saving = notifier.save('저장한 글');
      notifier.edit('저장 중에 더 쓴 글');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      h.network.holdCreate!.complete();
      final saved = (await saving)!;
      expect(await drafts.read(_draftToday), isNull);
      expect(
        await drafts.read(
          DiaryDraftTarget.existing(date: _today, id: saved.id),
        ),
        '저장 중에 더 쓴 글',
      );
      expect(
        h.container.read(diaryEditProvider(_newToday)).value!.status,
        DiaryDraftStatus.local,
      );
    });

    test('실패 경로의 초안 쓰기를 기다리는 중 들어온 입력도 디바운스로 초안에 남는다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      final drafts = h.container.read(diaryDraftStoreProvider);
      h.network.offline = true;
      h.draftWrites.hold = Completer<void>();
      final saving = notifier.save('첫 글');
      final failure = expectLater(saving, throwsA(isA<OfflineError>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      notifier.edit('쓰기를 기다리며 더 쓴 글');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      h.draftWrites.hold!.complete();
      await failure;
      h.draftWrites.hold = null;
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 100),
      );
      expect(await drafts.read(_draftToday), '쓰기를 기다리며 더 쓴 글');
    });

    test('성공 경로의 초안 쓰기를 기다리는 중 들어온 입력도 디바운스로 초안에 남는다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      final drafts = h.container.read(diaryDraftStoreProvider);
      h.network.holdCreate = Completer<void>();
      final saving = notifier.save('저장한 글');
      notifier.edit('저장 중에 더 쓴 글');
      h.draftWrites.hold = Completer<void>();
      h.network.holdCreate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      notifier.edit('쓰기를 기다리며 더 쓴 글');
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 50),
      );
      h.draftWrites.hold!.complete();
      final saved = (await saving)!;
      h.draftWrites.hold = null;
      await Future<void>.delayed(
        diaryDraftDelay + const Duration(milliseconds: 100),
      );
      expect(
        await drafts.read(
          DiaryDraftTarget.existing(date: _today, id: saved.id),
        ),
        '쓰기를 기다리며 더 쓴 글',
      );
    });

    test('저장 중에 화면을 떠나면 새 일기 초안에 쓰지 않고 저장 경로가 맡는다', () async {
      final h = await _harness();
      final subscription = h.container.listen(
        diaryEditProvider(_newToday),
        (_, _) {},
      );
      await h.container.read(diaryEditProvider(_newToday).future);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      final drafts = h.container.read(diaryDraftStoreProvider);
      h.network.holdCreate = Completer<void>();
      final saving = notifier.save('저장한 글');
      notifier.edit('저장 중에 더 쓴 글');
      subscription.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        await drafts.read(_draftToday),
        isNull,
        reason: '떠날 때 옛 대상(새 일기 초안)에 쓰지 않음',
      );
      h.network.holdCreate!.complete();
      final saved = (await saving)!;
      expect(await drafts.read(_draftToday), isNull);
      expect(
        await drafts.read(
          DiaryDraftTarget.existing(date: _today, id: saved.id),
        ),
        '저장 중에 더 쓴 글',
      );
    });

    test('고치기 저장은 update이고 그 일기 초안만 지운다', () async {
      final h = await _harness();
      final date = CalendarDate(2026, 10, 12);
      final id = await _idOn(h, date);
      final target = DiaryEditTarget.existing(id);
      final drafts = h.container.read(diaryDraftStoreProvider);
      final existingDraft = DiaryDraftTarget.existing(date: date, id: id);
      final newDraft = DiaryDraftTarget.newOn(date);
      await drafts.write(existingDraft, '고치던 글');
      await drafts.write(newDraft, '같은 날 새 글');
      await _edit(h, target);
      final saved = await h.container
          .read(diaryEditProvider(target).notifier)
          .save('고친 글');
      expect(saved!.id, id);
      expect(h.calls('updateDiary'), 1);
      expect(h.calls('createDiary'), 0);
      expect(await drafts.read(existingDraft), isNull);
      expect(await drafts.read(newDraft), '같은 날 새 글');
    });

    test('422 diary.day_full이면 초안을 남기고 ProblemError를 던진다', () async {
      final h = await _harness(scenarioId: 'diary-day-full');
      await _edit(h, _newToday);
      final notifier = h.container.read(diaryEditProvider(_newToday).notifier);
      await expectLater(
        notifier.save('열한째'),
        throwsA(
          isA<ProblemError>().having((e) => e.code, 'code', 'diary.day_full'),
        ),
      );
      expect(
        await h.container.read(diaryDraftStoreProvider).read(_draftToday),
        '열한째',
      );
      final state = h.container.read(diaryEditProvider(_newToday)).value!;
      expect(
        (state.status, state.offline, state.saving),
        (DiaryDraftStatus.local, false, false),
      );
    });

    test('오프라인 저장은 OfflineError이고 초안이 남으며 offline입니다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      h.network.offline = true;
      await expectLater(
        h.container.read(diaryEditProvider(_newToday).notifier).save('끊긴 글'),
        throwsA(isA<OfflineError>()),
      );
      expect(
        await h.container.read(diaryDraftStoreProvider).read(_draftToday),
        '끊긴 글',
      );
      final state = h.container.read(diaryEditProvider(_newToday)).value!;
      expect(
        (state.offline, state.saving, state.status),
        (true, false, DiaryDraftStatus.local),
      );
    });

    test('빈 본문은 저장하지 않습니다', () async {
      final h = await _harness();
      await _edit(h, _newToday);
      expect(
        await h.container
            .read(diaryEditProvider(_newToday).notifier)
            .save('  \n'),
        isNull,
      );
      expect(h.calls('createDiary'), 0);
    });

    test('오프라인으로 새 일기를 열면 초안으로 쓸 수 있고 offline입니다', () async {
      final h = await _harness();
      await h.container.read(diaryDraftStoreProvider).write(_draftToday, '초안');
      h.network.offline = true;
      final state = await _edit(h, _newToday);
      expect(state.initialBody, '초안');
      expect(state.offline, isTrue);
      expect(state.question, isNull);
    });

    test('저장 뒤 그날 diariesOnProvider를 다시 묻는다', () async {
      final h = await _harness();
      final subscription = h.container.listen(
        diariesOnProvider(_today),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await h.container.read(diariesOnProvider(_today).future);
      final before = h.calls('listDiaries');
      await _edit(h, _newToday);
      await h.container.read(diaryEditProvider(_newToday).notifier).save('글');
      final after = await h.container.read(diariesOnProvider(_today).future);
      expect(h.calls('listDiaries'), greaterThan(before));
      expect(after.map((d) => d.excerpt), contains('글'));
    });
  });

  group('diaryEditProvider 가이드 질문', () {
    test('질문을 기다리는 중 화면이 닫혀도 예상 못한 오류는 build에서 잡아 둔 보고기로 남깁니다', () async {
      final h = await _harness();
      final reporter =
          h.container.read(crashReporterProvider) as FakeCrashReporter;
      final hold = h.network.holdDailyThenFail = Completer<void>();
      h.container.listen(diaryEditProvider(_newToday), (_, _) {});
      // 초안 읽기를 지나 getDaily가 붙잡힐 때까지 기다립니다.
      await pumpEventQueue();
      h.container.dispose();
      hold.complete();
      await pumpEventQueue();
      expect(reporter.errors, hasLength(1));
    });
  });

  group('diaryDeleterProvider', () {
    test('지우면 그 일기 초안을 지우고 그날 일기 목록을 다시 묻습니다', () async {
      final h = await _harness();
      final date = CalendarDate(2026, 10, 12);
      final diary = (await h.container
          .read(diaryRepositoryProvider)
          .find(await _idOn(h, date)))!;
      final draft = DiaryDraftTarget.existing(date: date, id: diary.id);
      final drafts = h.container.read(diaryDraftStoreProvider);
      await drafts.write(draft, '초안');
      final subscription = h.container.listen(
        diariesOnProvider(date),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final before = (await h.container.read(diariesOnProvider(date).future))
          .length;
      expect(
        await h.container.read(diaryDeleterProvider.notifier).delete(diary),
        isTrue,
      );
      expect(await drafts.read(draft), isNull);
      expect(await h.container.read(diaryProvider(diary.id).future), isNull);
      expect(
        (await h.container.read(diariesOnProvider(date).future)).length,
        before - 1,
      );
    });

    test('이미 없으면(404) diary.not_found를 던지지만 그 일기 초안은 지웁니다', () async {
      final h = await _harness();
      final date = CalendarDate(2026, 10, 12);
      final diary = (await h.container
          .read(diaryRepositoryProvider)
          .find(await _idOn(h, date)))!;
      await h.container.read(diaryRepositoryProvider).delete(diary.id);
      final draft = DiaryDraftTarget.existing(date: date, id: diary.id);
      final drafts = h.container.read(diaryDraftStoreProvider);
      await drafts.write(draft, '초안');
      await expectLater(
        h.container.read(diaryDeleterProvider.notifier).delete(diary),
        throwsA(
          isA<ProblemError>().having((e) => e.code, 'code', 'diary.not_found'),
        ),
      );
      expect(await drafts.read(draft), isNull);
      expect(h.container.read(diaryDeleterProvider), isFalse);
    });
  });
}
