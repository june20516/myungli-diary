import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

import '../../../support/app_harness.dart';

const _october = CalendarMonth(2026, 10);
const _september = CalendarMonth(2026, 9);

/// `/v1/calendar/` 요청 경로를 남깁니다. [hold]에 있는 경로는 처음 한 번만 그 Completer가
/// 끝날 때까지 붙잡습니다. [unlockFromNow]가 켜진 뒤 출발한 요청의 응답은 `unlocked`로
/// 바꿉니다(잠금 해제 뒤의 server).
final class _CalendarTap extends Interceptor {
  final paths = <String>[];
  final hold = <String, Completer<void>>{};
  bool unlockFromNow = false;

  /// 돌아온 `/v1/calendar/` 응답 수.
  int responses = 0;

  static const _unlockedKey = 'calendarTap.unlocked';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.path.startsWith('/v1/calendar/')) {
      handler.next(options);
      return;
    }
    paths.add(options.path);
    options.extra[_unlockedKey] = unlockFromNow;
    final gate = hold.remove(options.path);
    if (gate != null) {
      await gate.future;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.path.startsWith('/v1/calendar/')) {
      responses++;
    }
    final body = response.data;
    if (response.requestOptions.extra[_unlockedKey] == true &&
        body is Map<String, dynamic>) {
      body['evidenceAccess'] = EvidenceAccess.unlocked.value;
    }
    handler.next(response);
  }
}

/// 대역 서버 앞에 [interceptor]를 끼웁니다(대역 서버는 항상 마지막).
void _insertBeforeFake(ProviderContainer container, Interceptor interceptor) {
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, interceptor);
}

/// 실제 I/O(asset·DB)와 가짜 시계 영역의 microtask·timer를 한 번씩 풀어 줍니다.
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

Future<(ProviderContainer, _CalendarTap)> _boot(
  WidgetTester tester, {
  String scenario = 'member',
}) async {
  final container = (await tester.runAsync(() => bootstrapForTest(scenario)))!;
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(entryStateProvider.future));
  expect(container.read(entryProvider), EntryState.ready);
  final tap = _CalendarTap();
  _insertBeforeFake(container, tap);
  return (container, tap);
}

/// [month]를 구독하고 값(또는 오류)이 나올 때까지 기다립니다.
Future<AsyncValue<Calendar>> _settle(
  WidgetTester tester,
  ProviderContainer container,
  CalendarMonth month,
) {
  final provider = calendarMonthProvider(month);
  final subscription = container.listen(provider, (_, _) {});
  addTearDown(subscription.close);
  return _until(
    tester,
    () => !container.read(provider).isLoading,
  ).then((_) => container.read(provider));
}

/// 사본으로 만든 [month]의 캐시 키.
Future<String> _keyFor(
  WidgetTester tester,
  ProviderContainer container,
  CalendarMonth month,
) async {
  final profile = (await tester.runAsync(
    () => container.read(cachedProfileProvider.future),
  ))!;
  return calendarKey(
    fingerprint: sajuFingerprint(profile),
    language: profile.language.value,
    year: month.year,
    month: month.month,
  );
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('사본의 키로 받아 저장하고, 다시 build해도 요청하지 않는다(A32)', (tester) async {
    final (container, tap) = await _boot(tester);

    final first = await _settle(tester, container, _october);
    expect(first.value!.month, 10);
    expect(tap.paths, ['/v1/calendar/2026/10']);
    final key = await _keyFor(tester, container, _october);
    final stored = await tester.runAsync(
      () => container.read(cacheStoreProvider).read(CacheKind.calendar, key),
    );
    expect(stored, isNotNull);

    container.invalidate(calendarMonthProvider(_october));
    final second = await _settle(tester, container, _october);
    expect(second.value!.month, 10);
    expect(tap.paths, hasLength(1));
  });

  testWidgets('같은 달을 동시에 읽으면 요청은 하나', (tester) async {
    final (container, tap) = await _boot(tester);

    final a = container.listen(calendarMonthProvider(_october), (_, _) {});
    final b = container.listen(calendarMonthProvider(_october), (_, _) {});
    addTearDown(a.close);
    addTearDown(b.close);
    await _until(
      tester,
      () => container.read(calendarMonthProvider(_october)).hasValue,
    );

    expect(tap.paths, ['/v1/calendar/2026/10']);
  });

  testWidgets('늦게 온 다른 달 응답이 보이는 달 상태를 바꾸지 않는다', (tester) async {
    final (container, tap) = await _boot(tester);
    final release = Completer<void>();
    tap.hold['/v1/calendar/2026/9'] = release;
    final septemberStates = <AsyncValue<Calendar>>[];
    final september = container.listen(
      calendarMonthProvider(_september),
      (_, next) => septemberStates.add(next),
    );
    addTearDown(september.close);
    await _until(tester, () => tap.paths.contains('/v1/calendar/2026/9'));

    final october = await _settle(tester, container, _october);
    final octoberStates = <AsyncValue<Calendar>>[];
    final octoberSubscription = container.listen(
      calendarMonthProvider(_october),
      (_, next) => octoberStates.add(next),
    );
    addTearDown(octoberSubscription.close);
    release.complete();
    await _until(tester, () => septemberStates.any((s) => s.hasValue));

    expect(octoberStates, isEmpty);
    expect(
      identical(
        container.read(calendarMonthProvider(_october)).value,
        october.value,
      ),
      isTrue,
    );
    expect(container.read(calendarMonthProvider(_september)).value!.month, 9);
  });

  testWidgets('server 오류는 자동 재시도 없이 오류 상태', (tester) async {
    final (container, tap) = await _boot(tester, scenario: 'calendar-error');

    final result = await _settle(tester, container, _october);

    expect(result.error, isA<ProblemError>());
    await _spin(tester);
    expect(tap.paths, hasLength(1));
  });

  group('calendarDayProvider', () {
    /// [date]를 구독하고 값(또는 오류)이 나올 때까지 기다립니다.
    Future<AsyncValue<CalendarDay>> settleDay(
      WidgetTester tester,
      ProviderContainer container,
      CalendarDate date,
    ) {
      final provider = calendarDayProvider(date);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      return _until(
        tester,
        () => !container.read(provider).isLoading,
      ).then((_) => container.read(provider));
    }

    testWidgets('그 날이 든 달을 받아 그 날을 고릅니다', (tester) async {
      final (container, tap) = await _boot(tester);

      final day = await settleDay(
        tester,
        container,
        CalendarDate(2026, 10, 12),
      );

      expect(day.value!.date, '2026-10-12');
      expect(day.value!.dayKind, DayKind.gwiinDay);
      expect(tap.paths, ['/v1/calendar/2026/10']);
    });

    testWidgets('달을 이미 들고 있으면 다시 요청하지 않습니다', (tester) async {
      final (container, tap) = await _boot(tester);
      await _settle(tester, container, _october);

      final day = await settleDay(
        tester,
        container,
        CalendarDate(2026, 10, 20),
      );

      expect(day.value!.date, '2026-10-20');
      expect(tap.paths, ['/v1/calendar/2026/10']);
    });

    testWidgets('달을 받지 못하면 같은 오류입니다', (tester) async {
      final (container, _) = await _boot(tester, scenario: 'calendar-error');

      final day = await settleDay(
        tester,
        container,
        CalendarDate(2026, 10, 12),
      );

      expect(day.hasValue, isFalse);
      expect(day.error, isA<AppError>());
    });
  });

  group('미리 받기', () {
    Future<void> prefetch(
      WidgetTester tester,
      ProviderContainer container,
      CalendarMonth visible,
    ) async {
      final subscription = container.listen(
        calendarPrefetchProvider(visible),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await _until(
        tester,
        () => container.read(calendarPrefetchProvider(visible)).hasValue,
      );
    }

    testWidgets('보이는 달의 앞뒤 한 달만 받는다', (tester) async {
      final (container, tap) = await _boot(tester);

      await prefetch(tester, container, _october);

      expect(tap.paths.toSet(), {
        '/v1/calendar/2026/9',
        '/v1/calendar/2026/11',
      });
      expect(tap.paths, hasLength(2));
      // 미리 받은 달은 화면이 열 때 다시 요청하지 않습니다.
      final september = await _settle(tester, container, _september);
      expect(september.value!.month, 9);
      expect(tap.paths, hasLength(2));
    });

    testWidgets('1900-01이면 이전 달(범위 밖)은 받지 않는다', (tester) async {
      final (container, tap) = await _boot(tester);

      await prefetch(tester, container, const CalendarMonth(1900, 1));

      expect(tap.paths, ['/v1/calendar/1900/2']);
    });

    testWidgets('2099-12이면 다음 달(범위 밖)은 받지 않는다', (tester) async {
      final (container, tap) = await _boot(tester);

      await prefetch(tester, container, const CalendarMonth(2099, 12));

      expect(tap.paths, ['/v1/calendar/2099/11']);
    });

    testWidgets('실패는 무시하고, 그 달은 화면이 열 때 다시 받는다', (tester) async {
      final (container, tap) = await _boot(tester, scenario: 'calendar-error');

      await prefetch(tester, container, _october);
      expect(
        container.read(calendarPrefetchProvider(_october)).hasError,
        isFalse,
      );
      expect(tap.paths, hasLength(2));

      await _settle(tester, container, _september);
      expect(tap.paths, hasLength(3));
    });
  });

  testWidgets(
    'CalendarUnlockSync.forgetLocked는 locked 달 캐시를 지우고 다음 진입에 다시 받게 한다',
    (tester) async {
      final (container, tap) = await _boot(tester);
      await _settle(tester, container, _october);
      final key = await _keyFor(tester, container, _october);
      expect(
        await tester.runAsync(
          () =>
              container.read(cacheStoreProvider).lockedKeys(CacheKind.calendar),
        ),
        [key],
      );

      await tester.runAsync(
        () => container.read(calendarUnlockSyncProvider).forgetLocked(),
      );
      await _until(tester, () => tap.paths.length == 2);

      expect(tap.paths, ['/v1/calendar/2026/10', '/v1/calendar/2026/10']);
    },
  );

  testWidgets('잠금 정리 전에 출발한 locked 응답은 정리 뒤에 도착해도 저장하지 않는다', (tester) async {
    final (container, tap) = await _boot(tester);
    final cache = container.read(cacheStoreProvider);
    final release = Completer<void>();
    tap.hold['/v1/calendar/2026/10'] = release;
    final states = <AsyncValue<Calendar>>[];
    final subscription = container.listen(
      calendarMonthProvider(_october),
      (_, next) => states.add(next),
    );
    addTearDown(subscription.close);
    await _until(tester, () => tap.paths.length == 1);

    // 잠금이 풀린 뒤의 server: 다시 받은 달은 unlocked로 저장됩니다.
    tap.unlockFromNow = true;
    await tester.runAsync(
      () => container.read(calendarUnlockSyncProvider).forgetLocked(),
    );
    await _until(
      tester,
      () =>
          container
              .read(calendarMonthProvider(_october))
              .value
              ?.evidenceAccess ==
          EvidenceAccess.unlocked,
    );
    expect(tap.paths, hasLength(2));

    // 붙잡아 둔 첫 요청(locked)이 이제 도착합니다.
    release.complete();
    await _until(tester, () => tap.responses == 2);
    // 응답 뒤의 캐시 쓰기(또는 건너뛰기)까지 돌립니다.
    for (var i = 0; i < 3; i++) {
      await _spin(tester);
    }

    final key = await _keyFor(tester, container, _october);
    expect(
      await tester.runAsync(() => cache.lockedKeys(CacheKind.calendar)),
      isEmpty,
    );
    expect(
      await tester.runAsync(() => cache.read(CacheKind.calendar, key)),
      isNotNull,
    );
  });
}
