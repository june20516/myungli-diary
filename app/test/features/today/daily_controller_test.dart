import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

import '../../support/app_harness.dart';
import '../../support/profile_sync_harness.dart' show ProfileServer;
import 'daily_repository_test.dart' show memberDailyJson;

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

/// [scenario]로 부팅하고 진입 계산이 끝나게 둡니다. [sync]면 시간대 동기화까지 끝냅니다.
Future<(ProviderContainer, _DailyTap)> _boot(
  WidgetTester tester, {
  String scenario = 'member',
  bool sync = true,
  List<Interceptor> before = const [],
}) async {
  final container = (await tester.runAsync(() => bootstrapForTest(scenario)))!;
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

/// 실제 I/O(asset·DB)와 가짜 시계 영역의 microtask를 한 번씩 풀어 줍니다.
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

/// 사본으로 만든 그날 캐시 키.
Future<String> _keyFor(
  WidgetTester tester,
  ProviderContainer container,
  CalendarDate date,
) async {
  final profile = (await tester.runAsync(
    () => container.read(cachedProfileProvider.future),
  ))!;
  return dailyKey(
    fingerprint: sajuFingerprint(profile),
    language: profile.language.value,
    date: date.toIso(),
  );
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

/// 날짜를 바꿀 수 있는 시계 보관함.
final class _ClockHolder extends Notifier<Clock> {
  @override
  Clock build() => noonClockOn(_today, 'Asia/Seoul');

  void moveTo(CalendarDate date) => state = noonClockOn(date, 'Asia/Seoul');
}

final _clockHolderProvider = NotifierProvider<_ClockHolder, Clock>(
  _ClockHolder.new,
);

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
    expect(values.last.stale, isFalse);
    expect(values.last.date, _today);
    expect(container.read(dailyControllerProvider.notifier).cacheKey, key);
    // 캐시가 새 응답으로 바뀌었습니다.
    final stored = await tester.runAsync(
      () => container.read(cacheStoreProvider).read(CacheKind.daily, key),
    );
    expect(
      (jsonDecode(stored!) as Map<String, dynamic>)['dayKind'],
      'yongsin_day',
    );
  });

  testWidgets('TimezoneSync가 끝난 뒤에 getDaily를 요청한다', (tester) async {
    final gate = _PatchGate();
    final (container, _) = await _boot(tester, sync: false, before: [gate]);
    // 앱 셸처럼 동기화를 시작합니다(사본이 없어 PATCH를 보냄).
    final sync = container.read(timezoneSyncProvider).syncIfChanged();

    final states = _record(container);
    for (var i = 0; i < 20; i++) {
      await _spin(tester);
    }
    expect(_fake(container).callCountOf('getDaily'), 0);
    expect(states.last.isLoading, isTrue);

    gate.release();
    var synced = false;
    unawaited(sync.whenComplete(() => synced = true));
    await _until(tester, () => synced);
    await _until(tester, () => _settled(states));

    expect(_fake(container).callCountOf('updateProfile'), 1);
    expect(_fake(container).callCountOf('getDaily'), 1);
    expect(states.last.value?.stale, isFalse);
    // 동기화가 만든 사본으로 키를 만들어 캐시에 남깁니다.
    final key = await _keyFor(tester, container, _today);
    expect(container.read(dailyControllerProvider.notifier).cacheKey, key);
  });

  testWidgets('사본이 없으면 캐시를 읽지도 쓰지도 않는다', (tester) async {
    // 시간대 PATCH가 실패해 사본이 생기지 않습니다(새 기기·재설치 회원).
    final (container, _) = await _boot(
      tester,
      before: [ProfileServer(failures: 1)],
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
    expect(container.read(dailyControllerProvider.notifier).cacheKey, isNull);
    expect(
      await tester.runAsync(
        () => container.read(cacheStoreProvider).lockedKeys(CacheKind.daily),
      ),
      isEmpty,
    );
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

  testWidgets('날짜가 바뀌면 새 날짜로 다시 받는다', (tester) async {
    final (root, tap) = await _boot(tester);
    // 부팅이 시계를 고정하므로 자식 컨테이너에서 시계를 바꿀 수 있게 덮습니다.
    // 오늘 계산도 자식에서 다시 하도록 같은 규칙(todayIn)으로 덮습니다.
    final container = ProviderContainer(
      parent: root,
      overrides: [
        clockProvider.overrideWith((ref) => ref.watch(_clockHolderProvider)),
        todayProvider.overrideWith(
          (ref) => todayIn(
            ref.watch(clockProvider),
            ref.watch(profileTimezoneProvider),
          ),
        ),
        dailyControllerProvider.overrideWith(DailyController.new),
      ],
    );
    addTearDown(container.dispose);

    final states = _record(container);
    await _until(tester, () => _settled(states));
    expect(states.last.value?.date, _today);

    final tomorrow = CalendarDate(2026, 10, 14);
    container.read(_clockHolderProvider.notifier).moveTo(tomorrow);
    await _until(
      tester,
      () => _settled(states) && states.last.value?.date == tomorrow,
    );

    expect(tap.paths, ['/v1/daily/2026-10-13', '/v1/daily/2026-10-14']);
    expect(states.last.value?.stale, isFalse);
    final tomorrowKey = await _keyFor(tester, container, tomorrow);
    expect(
      container.read(dailyControllerProvider.notifier).cacheKey,
      tomorrowKey,
    );
    expect(
      await tester.runAsync(
        () => container.read(cacheStoreProvider).lockedKeys(CacheKind.daily),
      ),
      containsAll([await _keyFor(tester, container, _today), tomorrowKey]),
    );
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

  testWidgets('cached profile이 바뀌면(사주 변경) 새 키로 다시 받는다', (tester) async {
    final (container, _) = await _boot(tester);
    final states = _record(container);
    await _until(tester, () => _settled(states));
    final before = container.read(dailyControllerProvider.notifier).cacheKey;

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
          container.read(dailyControllerProvider.notifier).cacheKey != before,
    );

    expect(_fake(container).callCountOf('getDaily'), 2);
    expect(
      container.read(dailyControllerProvider.notifier).cacheKey,
      await _keyFor(tester, container, _today),
    );
  });
}
