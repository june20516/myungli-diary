import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/model/schedule_draft.dart';
import 'package:myungli_diary/features/schedule/model/schedule_gone.dart';
import 'package:myungli_diary/features/schedule/model/schedule_range.dart';
import 'package:myungli_diary/features/schedule/model/today_schedule_summary.dart';

import '../../../support/schedule_test_server.dart';

final _today = CalendarDate(2026, 10, 13);

/// 2026년 10월의 6주 격자(09-27~11-07).
const _october = CalendarMonth(2026, 10);
final ScheduleRange _octoberGrid = (
  from: _october.gridStart,
  to: _october.gridEnd,
);

/// 2026년 11월의 6주 격자(11-01~12-12). 10월 일정과 겹치지 않습니다.
const _november = CalendarMonth(2026, 11);
final ScheduleRange _novemberGrid = (
  from: _november.gridStart,
  to: _november.gridEnd,
);

/// [server]로 답하고 오늘이 2026-10-13, 벽시계가 [now]인 컨테이너.
ProviderContainer _container(ScheduleTestServer server, {DateTime? now}) {
  final container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(server.client()),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      todayProvider.overrideWithValue(_today),
      nowMinuteProvider.overrideWith(
        (ref) => Stream.value(now ?? DateTime.utc(2026, 10, 13, 8)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// [range]를 구독하고 첫 값을 기다립니다.
Future<List<Schedule>> _hold(
  ProviderContainer container,
  ScheduleRange range,
) async {
  final provider = schedulesInRangeProvider(range);
  final subscription = container.listen(provider, (_, _) {});
  addTearDown(subscription.close);
  return await container.read(provider.future);
}

ScheduleDraft _walk() => ScheduleDraft(
  date: CalendarDate(2026, 10, 14),
  allDay: false,
  time: '08:30',
  title: '산책',
);

final ScheduleRange _todayRange = (from: _today, to: _today);

List<String> _titlesOf(ProviderContainer container, ScheduleRange range) => [
  for (final schedule in container.read(schedulesInRangeProvider(range)).value!)
    schedule.title,
];

int _listCount(ScheduleTestServer server) =>
    server.requestsOf('GET', '/v1/schedules').length;

void main() {
  group('schedulesInRangeProvider', () {
    test('범위를 한 번 받아 메모리에 들고, refresh로 다시 받는다(A34)', () async {
      final server = ScheduleTestServer();
      final container = _container(server);

      final first = await _hold(container, _octoberGrid);
      expect(first.map((s) => s.id), [
        'all-day',
        'morning',
        'evening',
        'dentist',
      ]);
      expect(_listCount(server), 1);
      expect(server.requests.single.queryParameters, {
        'from': '2026-09-27',
        'to': '2026-11-07',
      });

      await container
          .read(schedulesInRangeProvider(_octoberGrid).notifier)
          .refresh();
      expect(_listCount(server), 2);
    });

    test('오프라인에서 다시 받기가 실패해도 받아 둔 목록을 그대로 보인다(A34)', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      await _hold(container, _octoberGrid);

      server.offline = true;
      await container
          .read(schedulesInRangeProvider(_octoberGrid).notifier)
          .refresh();

      final state = container.read(schedulesInRangeProvider(_octoberGrid));
      expect(state.hasError, isFalse);
      expect(state.value, hasLength(4));
    });

    test('구독이 끝나도 들고 있다가, 로그아웃하면 버린다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final provider = schedulesInRangeProvider(_octoberGrid);
      final subscription = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      subscription.close();
      await container.pump();
      expect(container.exists(provider), isTrue);

      await container.read(tokenStoreProvider).signOut();
      await pumpEventQueue();
      await container.pump();

      expect(container.exists(provider), isFalse);
    });

    test('하루 범위는 구독이 끝나면 버린다(오늘이 바뀌면 지난 날이 남지 않음)', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final provider = schedulesInRangeProvider(_todayRange);
      final subscription = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      subscription.close();
      await container.pump();

      expect(container.exists(provider), isFalse);
    });

    test('첫 받기가 늦게 와도 저장 뒤 다시 받은 값을 덮지 않는다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final firstGet = server.holdNextGet();
      final provider = schedulesInRangeProvider(_octoberGrid);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await pumpEventQueue();

      await container.read(scheduleEditorProvider.notifier).save(_walk());
      expect(_titlesOf(container, _octoberGrid), contains('산책'));

      firstGet.complete();
      await pumpEventQueue();
      await container.pump();

      expect(_listCount(server), 2);
      expect(_titlesOf(container, _octoberGrid), contains('산책'));
    });

    test('겹친 다시 받기는 먼저 시작한 쪽이 늦게 끝나도 나중 값이 남는다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      await _hold(container, _octoberGrid);
      final notifier = container.read(
        schedulesInRangeProvider(_octoberGrid).notifier,
      );

      final olderGate = server.holdNextGet();
      final older = notifier.refresh();
      await pumpEventQueue();
      expect(_listCount(server), 2);
      server.store.create({
        'date': '2026-10-14',
        'allDay': true,
        'title': '새 일정',
      });
      await notifier.refresh();
      expect(_titlesOf(container, _octoberGrid), contains('새 일정'));

      olderGate.complete();
      await older;

      expect(_titlesOf(container, _octoberGrid), contains('새 일정'));
    });

    test('받은 적 없는 범위가 오프라인이면 오류 상태다', () async {
      final server = ScheduleTestServer()..offline = true;
      final container = _container(server);

      await expectLater(_hold(container, _octoberGrid), throwsA(anything));
      expect(
        container.read(schedulesInRangeProvider(_octoberGrid)).error,
        isA<OfflineError>(),
      );
    });
  });

  group('ScheduleEditor', () {
    test('만들기를 두 번 눌러도 요청은 1회이고 처리 중 누름은 무시한다', () async {
      final server = ScheduleTestServer()..hold = Completer<void>();
      final container = _container(server);
      final editor = container.read(scheduleEditorProvider.notifier);

      final first = editor.save(_walk());
      final second = await editor.save(_walk());
      expect(second, isNull);
      expect(container.read(scheduleEditorProvider), isTrue);

      server.hold!.complete();
      final created = await first;
      expect(created!.title, '산책');
      expect(server.requestsOf('POST', '/v1/schedules'), hasLength(1));
      expect(container.read(scheduleEditorProvider), isFalse);
    });

    test('실패 뒤 같은 초안을 다시 저장하면 같은 Idempotency-Key, 다른 초안이면 새 키', () async {
      final server = ScheduleTestServer()..writeFailureStatus = 503;
      final container = _container(server);
      final editor = container.read(scheduleEditorProvider.notifier);

      await expectLater(editor.save(_walk()), throwsA(isA<ProblemError>()));
      server.writeFailureStatus = null;
      await editor.save(_walk());
      await editor.save(_walk().copyWith(title: '달리기'));

      final keys = [
        for (final request in server.requestsOf('POST', '/v1/schedules'))
          request.headers['Idempotency-Key'] as String,
      ];
      expect(keys, hasLength(3));
      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[1]));
    });

    test('로그아웃하면 실패한 만들기의 대기 키를 버린다', () async {
      final server = ScheduleTestServer()..writeFailureStatus = 503;
      final container = _container(server);
      final editor = container.read(scheduleEditorProvider.notifier);
      await expectLater(editor.save(_walk()), throwsA(isA<ProblemError>()));

      await container.read(tokenStoreProvider).signOut();
      await pumpEventQueue();
      server.writeFailureStatus = null;
      await editor.save(_walk());

      final keys = [
        for (final request in server.requestsOf('POST', '/v1/schedules'))
          request.headers['Idempotency-Key'] as String,
      ];
      expect(keys, hasLength(2));
      expect(keys[1], isNot(keys[0]));
    });

    test('저장할 수 없는 초안은 요청 없이 StateError다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final noTime = ScheduleDraft(
        date: CalendarDate(2026, 10, 14),
        allDay: false,
        title: '산책',
      );

      await expectLater(
        container.read(scheduleEditorProvider.notifier).save(noTime),
        throwsStateError,
      );
      expect(server.requests, isEmpty);
      expect(container.read(scheduleEditorProvider), isFalse);
    });

    test('성공하면 그 날짜를 품은 범위만 다시 받는다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      await _hold(container, _octoberGrid);
      await _hold(container, _novemberGrid);
      expect(_listCount(server), 2);

      await container.read(scheduleEditorProvider.notifier).save(_walk());

      final refetched = server.requestsOf('GET', '/v1/schedules');
      expect(refetched, hasLength(3));
      expect(refetched.last.queryParameters['from'], '2026-09-27');
      expect(
        container
            .read(schedulesInRangeProvider(_octoberGrid))
            .value!
            .map((s) => s.title),
        contains('산책'),
      );
    });

    test('날짜를 옮기면 옛 날짜와 새 날짜의 범위를 모두 다시 받는다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final october = await _hold(container, _octoberGrid);
      await _hold(container, _novemberGrid);
      final dentist = october.firstWhere((s) => s.id == 'dentist');

      final moved = ScheduleDraft.of(dentist)
          .copyWith(date: CalendarDate(2026, 11, 3));
      await container
          .read(scheduleEditorProvider.notifier)
          .save(moved, original: dentist);

      expect(_listCount(server), 4);
      expect(
        container
            .read(schedulesInRangeProvider(_novemberGrid))
            .value!
            .single
            .id,
        'dentist',
      );
    });

    test('A36: 시각을 건드리지 않은 고치기 PATCH에는 time이 없다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final october = await _hold(container, _octoberGrid);
      final morning = october.firstWhere((s) => s.id == 'morning');

      await container
          .read(scheduleEditorProvider.notifier)
          .save(
            ScheduleDraft.of(morning).copyWith(title: '회고'),
            original: morning,
          );

      final patch = server.requestsOf('PATCH', '/v1/schedules/').single;
      expect(patch.data, isNot(contains('time')));
      expect(patch.data, contains('회고'));
    });

    test('404면 ScheduleGone을 알리고 범위를 다시 받는다(A41)', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final october = await _hold(container, _octoberGrid);
      final morning = october.firstWhere((s) => s.id == 'morning');
      server.store.delete('morning');

      await expectLater(
        container
            .read(scheduleEditorProvider.notifier)
            .save(
              ScheduleDraft.of(morning).copyWith(title: '회고'),
              original: morning,
            ),
        throwsA(isA<ScheduleGone>()),
      );
      expect(_listCount(server), 2);
      expect(
        container
            .read(schedulesInRangeProvider(_octoberGrid))
            .value!
            .map((s) => s.id),
        isNot(contains('morning')),
      );
      expect(container.read(scheduleEditorProvider), isFalse);
    });

    test('지우기 404도 ScheduleGone이고 범위를 다시 받는다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final october = await _hold(container, _octoberGrid);
      final morning = october.firstWhere((s) => s.id == 'morning');
      server.store.delete('morning');

      await expectLater(
        container.read(scheduleEditorProvider.notifier).delete(morning),
        throwsA(isA<ScheduleGone>()),
      );
      expect(_listCount(server), 2);
    });

    test('지우기에 성공하면 범위를 다시 받는다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final october = await _hold(container, _octoberGrid);
      final evening = october.firstWhere((s) => s.id == 'evening');

      final deleted = await container
          .read(scheduleEditorProvider.notifier)
          .delete(evening);

      expect(deleted, isTrue);
      expect(
        container.read(schedulesInRangeProvider(_octoberGrid)).value,
        hasLength(3),
      );
    });

    test('오프라인 저장은 서버에 닿는 요청 없이 OfflineError다(D47②)', () async {
      final server = ScheduleTestServer()..offline = true;
      final container = _container(server);

      await expectLater(
        container.read(scheduleEditorProvider.notifier).save(_walk()),
        throwsA(isA<OfflineError>()),
      );
      expect(server.requests, isEmpty);
      expect(container.read(scheduleEditorProvider), isFalse);
    });

    test('바뀐 것이 없는 고치기는 요청하지 않고 원래 일정을 돌려준다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final october = await _hold(container, _octoberGrid);
      final morning = october.firstWhere((s) => s.id == 'morning');

      final saved = await container
          .read(scheduleEditorProvider.notifier)
          .save(ScheduleDraft.of(morning), original: morning);

      expect(saved, morning);
      expect(server.requestsOf('PATCH', '/v1/schedules/'), isEmpty);
    });
  });

  group('todayScheduleSummaryProvider', () {
    Future<TodayScheduleSummary?> summaryAt(
      ScheduleTestServer server,
      DateTime now,
    ) async {
      final container = _container(server, now: now);
      final subscription = container.listen(
        todayScheduleSummaryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(nowMinuteProvider.future);
      try {
        await container.read(
          schedulesInRangeProvider((from: _today, to: _today)).future,
        );
      } on Object {
        // 실패 상태도 요약에서 확인합니다.
      }
      final summary = container.read(todayScheduleSummaryProvider);
      return summary;
    }

    test('오늘(today~today) 일정과 분 시계로 요약한다', () async {
      final server = ScheduleTestServer();

      expect(
        await summaryAt(server, DateTime.utc(2026, 10, 13, 10)),
        const TodayScheduleHighlight(
          status: TodayScheduleStatus.next,
          time: '19:00',
          title: '요가 수업',
          moreCount: 2,
        ),
      );
      expect(server.requests.single.queryParameters, {
        'from': '2026-10-13',
        'to': '2026-10-13',
      });
    });

    test('요약을 구독한 채 로그아웃하면 오늘 범위가 이전 값을 들고 있지 않다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      final subscription = container.listen(
        todayScheduleSummaryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(nowMinuteProvider.future);
      await container.read(schedulesInRangeProvider(_todayRange).future);
      expect(container.read(todayScheduleSummaryProvider), isNotNull);

      // 로그아웃 뒤 다시 받기는 붙잡아, 버린 뒤의 상태를 봅니다.
      final refetch = server.holdNextGet();
      addTearDown(refetch.complete);
      await container.read(tokenStoreProvider).signOut();
      await pumpEventQueue();

      final today = container.read(schedulesInRangeProvider(_todayRange));
      expect(today.isLoading, isTrue);
      expect(today.value, isEmpty);
      expect(container.read(todayScheduleSummaryProvider), isNull);
    });

    test('일정이 없으면 null', () async {
      final server = ScheduleTestServer(seed: const []);
      expect(await summaryAt(server, DateTime.utc(2026, 10, 13, 8)), isNull);
    });

    test('불러오지 못하면 null', () async {
      final server = ScheduleTestServer()..offline = true;
      expect(await summaryAt(server, DateTime.utc(2026, 10, 13, 8)), isNull);
    });

    test('오늘 일정을 만들면 요약이 바뀐다', () async {
      final server = ScheduleTestServer(seed: const []);
      final container = _container(server, now: DateTime.utc(2026, 10, 13, 8));
      final subscription = container.listen(
        todayScheduleSummaryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(nowMinuteProvider.future);
      await container.read(
        schedulesInRangeProvider((from: _today, to: _today)).future,
      );
      expect(container.read(todayScheduleSummaryProvider), isNull);

      await container
          .read(scheduleEditorProvider.notifier)
          .save(_walk().copyWith(date: _today));

      expect(
        container.read(todayScheduleSummaryProvider),
        isA<TodayScheduleHighlight>().having((s) => s.title, 'title', '산책'),
      );
    });
  });

  group('schedulesOnDateProvider', () {
    /// [date]를 구독하고 loading이 끝날 때까지 기다립니다.
    Future<AsyncValue<List<Schedule>>> onDate(
      ProviderContainer container,
      CalendarDate date,
    ) async {
      final provider = schedulesOnDateProvider(date);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      var state = container.read(provider);
      for (var i = 0; i < 50 && state.isLoading; i++) {
        await Future<void>.delayed(Duration.zero);
        state = container.read(provider);
      }
      return state;
    }

    test('들고 있는 격자가 없으면 그 날 하루만 받고, 하루 종일 먼저 시각순입니다', () async {
      final server = ScheduleTestServer(seed: [...memberSchedules().reversed]);
      final container = _container(server);

      final day = await onDate(container, _today);

      expect(day.value!.map((s) => s.id), ['all-day', 'morning', 'evening']);
      expect(server.requestsOf('GET', '/v1/schedules').single.queryParameters, {
        'from': '2026-10-13',
        'to': '2026-10-13',
      });
    });

    test('그 날을 품은 격자를 들고 있으면 다시 받지 않고 그 날만 거릅니다(A34)', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      await _hold(container, _octoberGrid);

      final day = await onDate(container, CalendarDate(2026, 10, 20));

      expect(day.value!.map((s) => s.id), ['dentist']);
      expect(_listCount(server), 1);
    });

    test('격자 범위에서 고른 날도 저장 뒤 다시 받은 목록을 따릅니다', () async {
      final server = ScheduleTestServer();
      final container = _container(server);
      await _hold(container, _octoberGrid);
      await onDate(container, CalendarDate(2026, 10, 14));

      await container.read(scheduleEditorProvider.notifier).save(_walk());

      expect(
        container
            .read(schedulesOnDateProvider(CalendarDate(2026, 10, 14)))
            .value!
            .map((s) => s.title),
        ['산책'],
      );
    });

    test('받지 못하면 오류 상태를 그대로 옮깁니다', () async {
      final server = ScheduleTestServer()..offline = true;
      final container = _container(server);

      final day = await onDate(container, _today);

      expect(day.hasValue, isFalse);
      expect(day.error, isA<AppError>());
    });
  });
}
