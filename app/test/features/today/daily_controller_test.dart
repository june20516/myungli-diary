import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/data/daily_repository.dart';

import '../../support/app_harness.dart';
import '../../support/daily_fixture.dart';
import '../../support/database_spies.dart';
import '../../support/profile_sync_harness.dart'
    show ProfileServer, seoulProfile;

final _today = CalendarDate(2026, 10, 13);

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// 대역 서버 앞에 [interceptor]를 끼웁니다(대역 서버는 항상 마지막).
void _insertBeforeFake(ProviderContainer container, Interceptor interceptor) {
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, interceptor);
}

/// `/v1/daily/` 요청 경로를 남기고, [offline]이면 연결 오류로 끊습니다.
final class _DailyTap extends Interceptor {
  final paths = <String>[];
  bool offline = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.path.startsWith('/v1/daily/')) {
      handler.next(options);
      return;
    }
    paths.add(options.path);
    if (offline) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

/// 처음 오는 `/v1/daily/` 요청 하나를 [release]까지 붙잡고, 그 뒤에 오는 요청은 503으로 끊습니다.
final class _HoldThenFail extends Interceptor {
  bool armed = false;
  bool held = false;
  final _release = Completer<void>();

  void release() => _release.complete();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!armed || !options.path.startsWith('/v1/daily/')) {
      handler.next(options);
      return;
    }
    if (!held) {
      held = true;
      await _release.future;
      handler.next(options);
      return;
    }
    handler.reject(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(requestOptions: options, statusCode: 503),
      ),
      true,
    );
  }
}

/// `/v1/daily/` 요청을 오는 순서대로 하나씩 붙잡고, [release]로 그 차례의 요청만 보냅니다.
final class _HoldEach extends Interceptor {
  bool armed = false;
  final _gates = <Completer<void>>[];

  /// 지금까지 붙잡은 요청 수.
  int get held => _gates.length;

  /// [index]번째로 붙잡은 요청을 보냅니다.
  void release(int index) => _gates[index].complete();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!armed || !options.path.startsWith('/v1/daily/')) {
      handler.next(options);
      return;
    }
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    handler.next(options);
  }
}

/// 프로필 수정(PATCH)을 [release]가 불릴 때까지 붙잡습니다.
final class _PatchGate extends Interceptor {
  final _released = Completer<void>();

  void release() => _released.complete();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method == 'PATCH') {
      await _released.future;
    }
    handler.next(options);
  }
}

/// 대역 서버에 닿은 요청을 `METHOD path`로 순서대로 남깁니다.
final class _RequestLog extends Interceptor {
  final requests = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add('${options.method} ${options.path}');
    handler.next(options);
  }
}

/// [scenario]로 부팅하고 진입 계산이 끝나게 둡니다. [sync]면 시간대 동기화까지 끝냅니다.
Future<(ProviderContainer, _DailyTap)> _boot(
  WidgetTester tester, {
  String scenario = 'member',
  bool sync = true,
  List<Interceptor> before = const [],
  QueryExecutor Function()? database,
}) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(scenario, database: database),
  ))!;
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(entryStateProvider.future));
  expect(container.read(entryProvider), EntryState.ready);
  final tap = _DailyTap();
  _insertBeforeFake(container, tap);
  for (final interceptor in before) {
    _insertBeforeFake(container, interceptor);
  }
  if (sync) {
    await tester.runAsync(
      () => container.read(timezoneSyncProvider).syncIfChanged(),
    );
  }
  return (container, tap);
}

/// [container]의 오늘 상태를 처음부터 모두 남깁니다.
List<AsyncValue<DailyView>> _record(ProviderContainer container) {
  final states = <AsyncValue<DailyView>>[];
  final subscription = container.listen(
    dailyControllerProvider,
    (_, next) => states.add(next),
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return states;
}

/// 실제 I/O(asset·DB)와 가짜 시계 영역의 microtask·timer를 한 번씩 풀어 줍니다.
///
/// build는 가짜 시계 영역에서 시작하므로 둘을 번갈아 돌려야 await 사슬이 나아갑니다.
Future<void> _spin(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// [done]이 참이 될 때까지 [_spin]합니다. 끝나지 않으면 테스트를 실패시킵니다.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300; i++) {
    if (done()) {
      return;
    }
    await _spin(tester);
  }
  fail('조건이 채워지지 않음');
}

/// 진행 중이 아니고 server 응답(또는 오류)까지 반영된 상태인지.
bool _settled(List<AsyncValue<DailyView>> states) =>
    states.isNotEmpty && !states.last.isLoading;

/// [profile]로 만든 [date]의 그날 캐시 키.
String _keyOf(Profile profile, CalendarDate date) => dailyKey(
  fingerprint: sajuFingerprint(profile),
  language: profile.language.value,
  date: date.toIso(),
);

/// 사본으로 만든 그날 캐시 키.
Future<String> _keyFor(
  WidgetTester tester,
  ProviderContainer container,
  CalendarDate date,
) async {
  final profile = (await tester.runAsync(
    () => container.read(cachedProfileProvider.future),
  ))!;
  return _keyOf(profile, date);
}

/// 그날 캐시에 [daily]를 직접 심습니다(규칙 버전 관찰 없이).
Future<void> _seed(
  WidgetTester tester,
  ProviderContainer container,
  String key,
  Daily daily,
) => tester
    .runAsync(
      () => container
          .read(cacheStoreProvider)
          .write(
            CacheKind.daily,
            key,
            jsonEncode(daily.toJson()),
            access: daily.evidenceAccess,
            rulesetVersion: daily.rulesetVersion,
          ),
    )
    .then((_) {});

/// server 응답과 구별되는 캐시 응답(평범한 날).
Daily _cachedDaily() =>
    Daily.fromJson({...memberDailyJson(), 'dayKind': 'ordinary_day'});

/// 내보낸 값(진행 중이 아닌 데이터)만 순서대로 모읍니다.
///
/// Riverpod 3은 이전 값을 둔 채 다시 받는 중을 `AsyncData(isLoading: true)`로 나타냅니다.
List<DailyView> _values(List<AsyncValue<DailyView>> states) => [
  for (final state in states)
    if (state case AsyncData(:final value) when !state.isLoading) value,
];

/// 손으로 옮기는, 시간이 흐르는 시계. 실제 `todayProvider`의 자정 구독이 동작합니다.
final class _MovableClock implements Clock {
  new(this.now);

  DateTime now;

  @override
  bool get advances => true;

  @override
  DateTime nowUtc() => now.toUtc();
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('사본이 있으면 캐시를 먼저 내보내고 server 응답으로 바꾼다', (tester) async {
    final (container, _) = await _boot(tester);
    final key = await _keyFor(tester, container, _today);
    await _seed(tester, container, key, _cachedDaily());

    final states = _record(container);
    await _until(tester, () => _settled(states) && _values(states).length == 2);

    final values = _values(states);
    expect(values.map((v) => v.daily.dayKind.value), [
      'ordinary_day',
      'yongsin_day',
    ]);
    expect(values.map((v) => v.cacheKey), [key, key]);
    expect(values.last.stale, isFalse);
    expect(values.last.date, _today);
    expect(container.read(dailyControllerProvider).value?.cacheKey, key);
    // 캐시가 새 응답으로 바뀌었습니다.
    final stored = await tester.runAsync(
      () => container.read(cacheStoreProvider).read(CacheKind.daily, key),
    );
    expect(
      (jsonDecode(stored!) as Map<String, dynamic>)['dayKind'],
      'yongsin_day',
    );
  });

  testWidgets('이전 형식 캐시(characterReason 없음)는 건너뛰고 server 응답으로 회복한다', (
    tester,
  ) async {
    final (container, _) = await _boot(tester);
    final key = await _keyFor(tester, container, _today);
    final legacy = {...memberDailyJson(), 'dayKind': 'ordinary_day'}
      ..remove('characterReason');
    await tester.runAsync(
      () => container
          .read(cacheStoreProvider)
          .write(
            CacheKind.daily,
            key,
            jsonEncode(legacy),
            access: EvidenceAccess.locked,
            rulesetVersion: 'r1',
          ),
    );

    final states = _record(container);
    await _until(tester, () => _settled(states));

    // 이전 캐시(평범한 날)는 내보내지 않고 server 응답만 보입니다.
    final values = _values(states);
    expect(values.map((v) => v.daily.dayKind.value), ['yongsin_day']);
    expect(values.single.stale, isFalse);
    // 캐시는 characterReason이 있는 새 형식으로 덮였습니다.
    final stored = await tester.runAsync(
      () => container.read(cacheStoreProvider).read(CacheKind.daily, key),
    );
    expect(
      (jsonDecode(stored!) as Map<String, dynamic>)['characterReason'],
      isNotNull,
    );
  });

  testWidgets('셸이 동기화를 시작하지 않아도 동기화(PATCH) 뒤에 getDaily를 요청한다', (tester) async {
    final gate = _PatchGate();
    final log = _RequestLog();
    // 사본이 없는 상태에서 셸보다 화면이 먼저 controller를 읽습니다.
    final (container, _) = await _boot(
      tester,
      sync: false,
      before: [gate, log],
    );

    final states = _record(container);
    for (var i = 0; i < 20; i++) {
      await _spin(tester);
    }
    // controller가 시작한 동기화의 PATCH가 붙잡혀 있는 동안 getDaily는 나가지 않습니다.
    expect(_fake(container).callCountOf('getDaily'), 0);
    expect(states.last.isLoading, isTrue);

    gate.release();
    await _until(tester, () => _settled(states));

    expect(log.requests, ['PATCH /v1/me/profile', 'GET /v1/daily/2026-10-13']);
    expect(states.last.value?.stale, isFalse);
    // 동기화가 만든 사본으로 키를 만들어 캐시에 남깁니다.
    final key = await _keyFor(tester, container, _today);
    expect(container.read(dailyControllerProvider).value?.cacheKey, key);
  });

  testWidgets('사본이 없으면 캐시를 읽지도 쓰지도 않는다', (tester) async {
    // 시간대 PATCH가 실패해 사본이 생기지 않습니다(새 기기·재설치 회원). 부팅 때와
    // controller가 다시 시도할 때 모두 실패합니다.
    final (container, _) = await _boot(
      tester,
      before: [ProfileServer(failures: 2)],
    );
    expect(
      await tester.runAsync(() => container.read(cachedProfileProvider.future)),
      isNull,
    );

    final states = _record(container);
    await _until(tester, () => _settled(states));

    final values = _values(states);
    expect(values, hasLength(1));
    expect(values.single.stale, isFalse);
    expect(values.single.cacheKey, isNull);
    expect(container.read(dailyControllerProvider).value?.cacheKey, isNull);
    expect(
      await tester.runAsync(
        () => container.read(cacheStoreProvider).lockedKeys(CacheKind.daily),
      ),
      isEmpty,
    );
  });

  testWidgets('사본이 없어도 응답의 rulesetVersion을 관찰해 사주 기반 캐시를 버린다', (tester) async {
    final (container, _) = await _boot(
      tester,
      before: [ProfileServer(failures: 2)],
    );
    final cache = container.read(cacheStoreProvider);
    await tester.runAsync(() async {
      await cache.observeRulesetVersion('r0');
      await cache.write(
        CacheKind.calendar,
        'fingerprint|ko|2026-10',
        '{}',
        access: EvidenceAccess.locked,
        rulesetVersion: 'r0',
      );
    });

    final states = _record(container);
    await _until(tester, () => _settled(states));

    expect(states.last.value?.cacheKey, isNull);
    expect(
      await tester.runAsync(
        () => cache.read(CacheKind.calendar, 'fingerprint|ko|2026-10'),
      ),
      isNull,
    );
  });

  testWidgets('그날 캐시 쓰기가 실패해도 server 응답을 보이고 오류만 보고한다', (tester) async {
    final failure = FailingInserts('cached_responses', arg: 'daily');
    final (container, _) = await _boot(
      tester,
      database: () => NativeDatabase.memory().interceptWith(failure),
    );
    failure.failing = true;

    final states = _record(container);
    await _until(tester, () => _settled(states));

    final view = states.last.value!;
    expect(states.last.hasError, isFalse);
    expect(view.daily.dayKind.value, 'yongsin_day');
    expect(view.stale, isFalse);
    final reporter = container.read(crashReporterProvider) as FakeCrashReporter;
    expect(reporter.errors.map((e) => e.errorType), contains('StateError'));
  });

  testWidgets('오프라인이고 오늘 키 캐시가 있으면 stale 캐시', (tester) async {
    final (container, tap) = await _boot(tester);
    final key = await _keyFor(tester, container, _today);
    await _seed(tester, container, key, _cachedDaily());
    tap.offline = true;

    final states = _record(container);
    await _until(tester, () => _settled(states) && _values(states).length == 2);

    final last = _values(states).last;
    expect(last.stale, isTrue);
    expect(last.daily.dayKind.value, 'ordinary_day');
    expect(last.date, _today);
    expect(last.cacheKey, key);
  });

  testWidgets('오프라인이고 어제 키만 있으면 OfflineError', (tester) async {
    final (container, tap) = await _boot(tester);
    final yesterday = CalendarDate(2026, 10, 12);
    final yesterdayKey = await _keyFor(tester, container, yesterday);
    await _seed(
      tester,
      container,
      yesterdayKey,
      Daily.fromJson({...memberDailyJson(), 'date': '2026-10-12'}),
    );
    tap.offline = true;

    final states = _record(container);
    await _until(tester, () => _settled(states));

    // 어제 캐시를 오늘로 보이지 않습니다(A24).
    expect(_values(states), isEmpty);
    expect(states.last.error, isA<OfflineError>());
  });

  testWidgets('server 오류면 AppError로 실패하고 reload로 다시 받는다', (tester) async {
    final (container, _) = await _boot(tester, scenario: 'daily-error');

    final states = _record(container);
    await _until(tester, () => _settled(states));

    final error = states.last.error;
    expect(error, isA<ProblemError>());
    expect((error! as ProblemError).code, 'service.unavailable');
    expect(_fake(container).callCountOf('getDaily'), 1);

    final countBefore = states.length;
    var reloaded = false;
    unawaited(
      container
          .read(dailyControllerProvider.notifier)
          .reload()
          .whenComplete(() => reloaded = true),
    );
    await _until(tester, () => reloaded);

    expect(_fake(container).callCountOf('getDaily'), 2);
    // 다시 받는 동안 진행 중이었다가 다시 오류입니다.
    expect(states.skip(countBefore).first.isLoading, isTrue);
    expect(states.last.error, isA<ProblemError>());
  });

  testWidgets('reload는 캐시를 건너뛰고 server 응답만 다시 받는다', (tester) async {
    final (container, _) = await _boot(tester);
    final key = await _keyFor(tester, container, _today);
    final states = _record(container);
    await _until(tester, () => _settled(states));
    // 받은 뒤 캐시를 구별되는 값으로 바꿔 둡니다.
    await _seed(tester, container, key, _cachedDaily());

    final countBefore = states.length;
    var reloaded = false;
    unawaited(
      container
          .read(dailyControllerProvider.notifier)
          .reload()
          .whenComplete(() => reloaded = true),
    );
    await _until(tester, () => reloaded);
    await _until(tester, () => _settled(states));

    final afterReload = _values(states.skip(countBefore).toList());
    expect(afterReload.map((v) => v.daily.dayKind.value), ['yongsin_day']);
    expect(_fake(container).callCountOf('getDaily'), 2);
    // 다시 받은 응답이 캐시를 덮었습니다.
    final stored = await tester.runAsync(
      () => container.read(cacheStoreProvider).read(CacheKind.daily, key),
    );
    expect(
      (jsonDecode(stored!) as Map<String, dynamic>)['dayKind'],
      'yongsin_day',
    );
  });

  testWidgets('refreshQuietly: 진행 중 상태 없이 캐시를 건너뛰고 받아 값과 캐시를 바꾼다', (
    tester,
  ) async {
    final (container, _) = await _boot(tester, scenario: 'reward-unlock');
    final key = await _keyFor(tester, container, _today);
    final states = _record(container);
    await _until(tester, () => _settled(states));
    expect(states.last.value!.daily.evidenceAccess, EvidenceAccess.locked);
    await _seed(tester, container, key, _cachedDaily());

    final countBefore = states.length;
    var done = false;
    unawaited(
      container
          .read(dailyControllerProvider.notifier)
          .refreshQuietly()
          .whenComplete(() => done = true),
    );
    await _until(tester, () => done);

    final after = states.skip(countBefore).toList();
    expect(after.any((s) => s.isLoading), isFalse, reason: '오늘 화면은 그대로');
    expect(after.single.value!.daily.evidenceAccess, EvidenceAccess.unlocked);
    expect(after.single.value!.cacheKey, key);
    expect(_fake(container).callCountOf('getDaily'), 2);
    final stored = await tester.runAsync(
      () => container.read(cacheStoreProvider).read(CacheKind.daily, key),
    );
    expect(
      (jsonDecode(stored!) as Map<String, dynamic>)['evidenceAccess'],
      'unlocked',
    );
  });

  testWidgets('refreshQuietly: 실패하면 상태는 이전 값 그대로 두고 오류를 던진다', (tester) async {
    final (container, tap) = await _boot(tester);
    final states = _record(container);
    await _until(tester, () => _settled(states));
    final countBefore = states.length;
    tap.offline = true;

    Object? thrown;
    var done = false;
    unawaited(
      container
          .read(dailyControllerProvider.notifier)
          .refreshQuietly()
          .then<void>((_) {}, onError: (Object error) => thrown = error)
          .whenComplete(() => done = true),
    );
    await _until(tester, () => done);

    expect(thrown, isA<OfflineError>());
    expect(states.length, countBefore, reason: '상태가 바뀌지 않음');
    expect(container.read(dailyControllerProvider).hasError, isFalse);
  });

  testWidgets('refreshQuietly: 보일 값이 없어 reload로 받을 때 실패하면 그 오류를 던진다', (
    tester,
  ) async {
    final (container, _) = await _boot(tester, scenario: 'daily-error');
    final states = _record(container);
    await _until(tester, () => _settled(states));
    expect(states.last.hasValue, isFalse);

    Object? thrown;
    var done = false;
    unawaited(
      container
          .read(dailyControllerProvider.notifier)
          .refreshQuietly()
          .then<void>((_) {}, onError: (Object error) => thrown = error)
          .whenComplete(() => done = true),
    );
    await _until(tester, () => done);

    expect(thrown, isA<ProblemError>());
  });

  testWidgets('refreshQuietly: 받는 중에 다시 build되면 새 build 결과를 따르고 실패면 던진다', (
    tester,
  ) async {
    final (container, _) = await _boot(tester);
    final states = _record(container);
    await _until(tester, () => _settled(states));
    final gate = _HoldThenFail();
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, gate);
    gate.armed = true;

    Object? thrown;
    var done = false;
    unawaited(
      container
          .read(dailyControllerProvider.notifier)
          .refreshQuietly()
          .then<void>((_) {}, onError: (Object error) => thrown = error)
          .whenComplete(() => done = true),
    );
    await _until(tester, () => gate.held);
    // 받는 중에 다시 build됩니다(자정·사본 변경 흉내). 새 build의 요청은 503입니다.
    container.invalidate(dailyControllerProvider);
    await _until(
      tester,
      () => container.read(dailyControllerProvider).hasError,
    );
    gate.release();
    await _until(tester, () => done);

    // 받아 둔 성공 응답은 버리고 새 build의 오류를 그대로 던집니다.
    expect(thrown, isA<AppError>());
    expect(
      identical(thrown, container.read(dailyControllerProvider).error),
      isTrue,
    );
  });

  testWidgets('refreshQuietly: 받은 뒤 새 build가 아직 받는 중이면 끝날 때까지 기다려 그 결과를 따른다', (
    tester,
  ) async {
    final (container, _) = await _boot(tester);
    final states = _record(container);
    await _until(tester, () => _settled(states));
    final before = container.read(dailyControllerProvider).value;
    final gate = _HoldEach();
    _insertBeforeFake(container, gate);
    gate.armed = true;

    Object? thrown;
    var done = false;
    unawaited(
      container
          .read(dailyControllerProvider.notifier)
          .refreshQuietly()
          .then<void>((_) {}, onError: (Object error) => thrown = error)
          .whenComplete(() => done = true),
    );
    await _until(tester, () => gate.held == 1);
    // 받는 중에 다시 build됩니다(자정·사본 변경 흉내). 새 build의 요청도 붙잡아 둡니다.
    container.invalidate(dailyControllerProvider);
    await _until(tester, () => gate.held == 2);

    // 첫 요청을 풀어도 새 build가 아직 받는 중이므로 끝나지 않습니다.
    gate.release(0);
    for (var i = 0; i < 5; i++) {
      await _spin(tester);
    }
    // 새 build는 캐시를 먼저 보이지만 server 응답 전이므로 아직 끝나지 않습니다.
    expect(done, isFalse);

    // 새 build를 풀면 그 결과(server 응답)를 따르고 던지지 않습니다.
    gate.release(1);
    await _until(tester, () => done);
    expect(thrown, isNull);
    final after = container.read(dailyControllerProvider);
    expect(after.isLoading, isFalse);
    expect(after.value?.fromCache, isFalse);
    expect(after.value?.stale, isFalse);
    expect(identical(after.value, before), isFalse);
  });

  testWidgets('cached profile이 바뀌면(사주 변경) 새 키로 다시 받는다', (tester) async {
    final (container, _) = await _boot(tester);
    final states = _record(container);
    await _until(tester, () => _settled(states));
    final before = container.read(dailyControllerProvider).value?.cacheKey;

    // 사주를 바꾼 저장 응답이 사본을 바꿉니다.
    final profile = (await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    ))!;
    await tester.runAsync(
      () => container
          .read(cacheStoreProvider)
          .write(
            CacheKind.profile,
            'profile',
            jsonEncode({
              ...profile.toJson(),
              'birth': {...profile.birth.toJson(), 'gender': 'male'},
            }),
            access: EvidenceAccess.unlocked,
          ),
    );
    container.invalidate(cachedProfileProvider);
    await _until(
      tester,
      () =>
          _settled(states) &&
          container.read(dailyControllerProvider).value?.cacheKey != before,
    );

    expect(_fake(container).callCountOf('getDaily'), 2);
    expect(
      container.read(dailyControllerProvider).value?.cacheKey,
      await _keyFor(tester, container, _today),
    );
  });

  // 부팅은 시나리오 날짜로 고정 시계(FixedClock)를 덮어 자정이 오지 않으므로, 이 테스트는
  // 부팅 없이 컨테이너를 만들어 실제 todayProvider(흐르는 시계 + 자정 구독)를 씁니다.
  testWidgets('화면이 열린 채 자정을 넘기면 새 날짜로 다시 받는다', (tester) async {
    // 한국 시간 2026-10-13 23:59:50.
    final clock = _MovableClock(DateTime.utc(2026, 10, 13, 14, 59, 50));
    final server = ScriptedDailyServer();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..interceptors.add(server);
    final database = AppDatabase.forExecutor(NativeDatabase.memory());
    final cache = CacheStore(database, accountId: 'account-1');
    final reporter = FakeCrashReporter();
    final profile = Profile.fromJson(seoulProfile);
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        profileTimezoneProvider.overrideWithValue('Asia/Seoul'),
        // 진입이 ready가 아니면 동기화는 바로 끝납니다(이 테스트의 관심 밖).
        entryProvider.overrideWithValue(null),
        cachedProfileProvider.overrideWith((ref) => profile),
        crashReporterProvider.overrideWithValue(reporter),
        dailyRepositoryProvider.overrideWithValue(
          DailyRepository(DefaultApi(dio), cache, reporter),
        ),
      ],
    );
    Future<void> pumpUntil(bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(done(), isTrue, reason: '조건이 채워지지 않음');
    }

    final states = <AsyncValue<DailyView>>[];
    final subscription = container.listen(
      dailyControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    await pumpUntil(() => _settled(states));
    final todayKey = _keyOf(profile, _today);
    expect(states.last.value?.date, _today);
    expect(container.read(dailyControllerProvider).value?.cacheKey, todayKey);

    // 자정을 넘깁니다. 새 날짜 응답은 잠시 붙잡아 다시 받는 중을 관찰합니다.
    final hold = server.hold = Completer<void>();
    clock.now = DateTime.utc(2026, 10, 13, 15, 0, 10);
    await tester.pump(const Duration(seconds: 31));
    await pumpUntil(() => server.paths.length == 2);

    // 다시 받는 동안 이전 날짜 값을 보이고, 키도 보이는 값(이전 날짜)의 키입니다.
    expect(states.last.isLoading, isTrue);
    expect(states.last.value?.date, _today);
    expect(container.read(dailyControllerProvider).value?.cacheKey, todayKey);

    hold.complete();
    await pumpUntil(() => _settled(states));

    final tomorrow = CalendarDate(2026, 10, 14);
    expect(server.paths, ['/v1/daily/2026-10-13', '/v1/daily/2026-10-14']);
    expect(states.last.value?.date, tomorrow);
    expect(states.last.value?.stale, isFalse);
    expect(
      container.read(dailyControllerProvider).value?.cacheKey,
      _keyOf(profile, tomorrow),
    );

    // 자정 구독 timer가 남지 않게 테스트 안에서 정리합니다.
    subscription.close();
    container.dispose();
    await database.close();
  });
}
