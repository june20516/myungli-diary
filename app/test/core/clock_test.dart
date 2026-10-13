import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';

/// 테스트가 직접 진행시키는 시계.
final class _MutableClock implements Clock {
  new(this.now);

  DateTime now;

  @override
  bool get advances => true;

  @override
  DateTime nowUtc() => now;
}

final class _ThrowingClock implements Clock {
  bool shouldThrow = false;

  @override
  bool get advances => true;

  @override
  DateTime nowUtc() =>
      shouldThrow ? throw StateError('boom') : DateTime.utc(2026, 10, 13);
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('CalendarDate', () {
    test('parse와 toIso가 왕복한다', () {
      final date = CalendarDate.parse('2026-10-13');
      expect((date.year, date.month, date.day), (2026, 10, 13));
      expect(date.toIso(), '2026-10-13');
    });

    test('형식이 틀리거나 없는 날짜면 FormatException', () {
      for (final bad in ['2026-02-30', '2026-13-01', '2026-1-1', 'abc', '']) {
        expect(
          () => CalendarDate.parse(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('한 자리 월·일은 0으로 채워 toIso', () {
      expect(CalendarDate(2026, 1, 5).toIso(), '2026-01-05');
    });

    test('생성자에 없는 날짜를 주면 ArgumentError', () {
      expect(() => CalendarDate(2026, 2, 30), throwsArgumentError);
    });

    test('compareTo는 월과 일도 비교한다', () {
      expect(
        CalendarDate(2026, 3, 1).compareTo(CalendarDate(2026, 4, 1)),
        lessThan(0),
      );
      expect(
        CalendarDate(2026, 4, 1).compareTo(CalendarDate(2026, 3, 31)),
        greaterThan(0),
      );
      expect(
        CalendarDate(2026, 3, 5).compareTo(CalendarDate(2026, 3, 9)),
        lessThan(0),
      );
      expect(
        CalendarDate(2026, 3, 9).compareTo(CalendarDate(2026, 3, 5)),
        greaterThan(0),
      );
      expect(CalendarDate(2026, 3, 9).compareTo(CalendarDate(2026, 3, 9)), 0);
    });

    test('같음과 순서', () {
      expect(CalendarDate.parse('2026-10-13'), CalendarDate(2026, 10, 13));
      expect(
        CalendarDate.parse('2026-10-13').hashCode,
        CalendarDate(2026, 10, 13).hashCode,
      );
      expect(
        CalendarDate(2026, 10, 13).compareTo(CalendarDate(2026, 10, 14)),
        lessThan(0),
      );
      expect(
        CalendarDate(2027, 1, 1).compareTo(CalendarDate(2026, 12, 31)),
        greaterThan(0),
      );
    });
  });

  group('todayIn', () {
    final instant = DateTime.utc(2026, 10, 13, 15, 30);

    test('같은 순간이 시간대마다 다른 날짜가 된다', () {
      final clock = FixedClock(instant);
      expect(todayIn(clock, 'Asia/Seoul'), CalendarDate(2026, 10, 14));
      expect(todayIn(clock, 'America/Los_Angeles'), CalendarDate(2026, 10, 13));
    });

    test('Pacific/Kiritimati(UTC+14) 경계', () {
      expect(
        todayIn(
          FixedClock(DateTime.utc(2026, 10, 13, 9, 59)),
          'Pacific/Kiritimati',
        ),
        CalendarDate(2026, 10, 13),
      );
      expect(
        todayIn(
          FixedClock(DateTime.utc(2026, 10, 13, 10)),
          'Pacific/Kiritimati',
        ),
        CalendarDate(2026, 10, 14),
      );
    });

    test('모르는 IANA 이름이면 ArgumentError', () {
      expect(
        () => todayIn(FixedClock(instant), 'Mars/Olympus'),
        throwsArgumentError,
      );
    });

    test('SystemClock은 UTC 시각을 준다', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });
  });

  group('dayChanges', () {
    test('구독 직후에는 내보내지 않고 자정을 넘길 때 정확히 한 번 내보낸다', () {
      fakeAsync((async) {
        // 서울 2026-10-13 23:58 = UTC 14:58
        final clock = _MutableClock(DateTime.utc(2026, 10, 13, 14, 58));
        final seen = <CalendarDate>[];
        final sub = dayChanges(clock, 'Asia/Seoul').listen(seen.add);

        async.elapse(Duration.zero);
        expect(seen, isEmpty);

        for (var i = 0; i < 8; i++) {
          clock.now = clock.now.add(const Duration(seconds: 30));
          async.elapse(const Duration(seconds: 30));
        }
        // 이제 서울 00:02
        expect(seen, [CalendarDate(2026, 10, 14)]);

        for (var i = 0; i < 10; i++) {
          clock.now = clock.now.add(const Duration(seconds: 30));
          async.elapse(const Duration(seconds: 30));
        }
        expect(seen, hasLength(1));
        unawaited(sub.cancel());
      });
    });

    test('프로필 시간대가 기기와 달라도 프로필 자정에 바뀐다', () {
      fakeAsync((async) {
        // LA 2026-10-13 23:59 = UTC 10-14 06:59
        final clock = _MutableClock(DateTime.utc(2026, 10, 14, 6, 59));
        final seen = <CalendarDate>[];
        final sub = dayChanges(
          clock,
          'America/Los_Angeles',
          tick: const Duration(seconds: 10),
        ).listen(seen.add);

        clock.now = clock.now.add(const Duration(minutes: 2));
        async.elapse(const Duration(seconds: 10));
        expect(seen, [CalendarDate(2026, 10, 14)]);
        unawaited(sub.cancel());
      });
    });

    test('뉴욕 서머타임 종료일(2026-11-01) 자정 전후에 하루만 바뀐다', () {
      fakeAsync((async) {
        // 뉴욕 11-01 00:00 EDT = UTC 04:00. 01:00~02:00는 두 번 옴(EDT, EST).
        // 시작: UTC 10-31 23:59 = 뉴욕 10-31 19:59 EDT.
        final clock = _MutableClock(DateTime.utc(2026, 10, 31, 23, 59));
        final seen = <CalendarDate>[];
        final sub = dayChanges(
          clock,
          'America/New_York',
          tick: const Duration(minutes: 1),
        ).listen(seen.add);

        // 자정(UTC 04:00)을 넘겨 UTC 06:00(뉴욕 01:00 EST)까지 진행.
        final end = DateTime.utc(2026, 11, 1, 6);
        while (clock.now.isBefore(end)) {
          clock.now = clock.now.add(const Duration(minutes: 1));
          async.elapse(const Duration(minutes: 1));
        }
        expect(seen, [CalendarDate(2026, 11, 1)]);

        // 11-01 자정 직후 1분, 직전 1분 값도 확인
        expect(
          todayIn(
            FixedClock(DateTime.utc(2026, 11, 1, 3, 59)),
            'America/New_York',
          ),
          CalendarDate(2026, 10, 31),
        );
        expect(
          todayIn(
            FixedClock(DateTime.utc(2026, 11, 1, 4, 1)),
            'America/New_York',
          ),
          CalendarDate(2026, 11, 1),
        );

        // 뉴욕 01:30이 두 번 오는 구간(UTC 05:30, 06:30)을 지나도 다시 내보내지 않는다.
        final after = DateTime.utc(2026, 11, 1, 8);
        while (clock.now.isBefore(after)) {
          clock.now = clock.now.add(const Duration(minutes: 1));
          async.elapse(const Duration(minutes: 1));
        }
        expect(seen, hasLength(1));
        unawaited(sub.cancel());
      });
    });

    test('구독을 취소하면 더 폴링하지 않는다', () {
      fakeAsync((async) {
        final clock = _MutableClock(DateTime.utc(2026, 10, 13, 14, 59));
        final seen = <CalendarDate>[];
        final sub = dayChanges(clock, 'Asia/Seoul').listen(seen.add);
        unawaited(sub.cancel());
        clock.now = clock.now.add(const Duration(hours: 1));
        async.elapse(const Duration(hours: 1));
        expect(seen, isEmpty);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('provider', () {
    Scenario scenario() => Scenario(
      id: 's',
      today: CalendarDate(2026, 10, 13),
      timezone: 'Asia/Seoul',
    );

    ProviderContainer container(ApiMode mode) {
      final c = ProviderContainer(
        overrides: [
          apiModeProvider.overrideWithValue(mode),
          scenarioProvider.overrideWithValue(scenario()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('fake 모드는 시나리오 timezone 현지 정오에 고정되고 오늘이 시나리오 today다', () {
      final c = container(ApiMode.fake);
      expect(c.read(clockProvider).nowUtc(), DateTime.utc(2026, 10, 13, 3));
      expect(c.read(profileTimezoneProvider), 'Asia/Seoul');
      expect(c.read(todayProvider), CalendarDate(2026, 10, 13));
    });

    test('시나리오 timezone이 모르는 이름이면 ArgumentError', () {
      final c = ProviderContainer(
        overrides: [
          apiModeProvider.overrideWithValue(ApiMode.fake),
          scenarioProvider.overrideWithValue(
            Scenario(
              id: 's',
              today: CalendarDate(2026, 10, 13),
              timezone: 'Mars/Olympus',
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      // Riverpod이 provider 오류를 ProviderException으로 감싸므로 원인 문구로 확인한다.
      expect(
        () => c.read(clockProvider),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'message',
            contains('모르는 시간대입니다'),
          ),
        ),
      );
    });

    test('todayProvider는 자정을 넘기면 한 번 새 날짜로 갱신된다', () {
      fakeAsync((async) {
        // 서울 10-13 23:59 = UTC 14:59
        final clock = _MutableClock(DateTime.utc(2026, 10, 13, 14, 59));
        final c = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            profileTimezoneProvider.overrideWithValue('Asia/Seoul'),
          ],
        );
        final seen = <CalendarDate>[];
        c.listen(
          todayProvider,
          (_, next) => seen.add(next),
          fireImmediately: true,
        );
        expect(seen, [CalendarDate(2026, 10, 13)]);

        for (var i = 0; i < 6; i++) {
          clock.now = clock.now.add(const Duration(seconds: 30));
          async.elapse(const Duration(seconds: 30));
        }
        expect(c.read(todayProvider), CalendarDate(2026, 10, 14));
        expect(seen, [CalendarDate(2026, 10, 13), CalendarDate(2026, 10, 14)]);

        for (var i = 0; i < 20; i++) {
          clock.now = clock.now.add(const Duration(seconds: 30));
          async.elapse(const Duration(seconds: 30));
        }
        expect(seen, hasLength(2));

        c.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('고정 시계면 todayProvider는 타이머를 만들지 않는다', () {
      fakeAsync((async) {
        container(ApiMode.fake).read(todayProvider);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('dayChanges는 날짜 계산 실패를 스트림 오류로 전달한다', () {
      fakeAsync((async) {
        final clock = _ThrowingClock();
        final errors = <Object>[];
        final sub = dayChanges(
          clock,
          'Asia/Seoul',
        ).listen((_) {}, onError: errors.add);
        clock.shouldThrow = true;
        async.elapse(const Duration(seconds: 30));
        expect(errors, hasLength(1));
        unawaited(sub.cancel());
      });
    });

    test('http 모드는 SystemClock이다', () {
      final c = container(ApiMode.http);
      expect(c.read(clockProvider), isA<SystemClock>());
    });
  });
}
