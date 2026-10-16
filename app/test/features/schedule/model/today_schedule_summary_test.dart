import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/features/schedule/model/today_schedule_summary.dart';

import '../schedule_test_server.dart';

/// member 시나리오 2026-10-13 일정(하루 종일·09:07·19:00).
List<Schedule> _today({bool withAllDay = true}) => [
  for (final json in memberSchedules())
    if (json['date'] == '2026-10-13' && (withAllDay || json['allDay'] != true))
      Schedule.fromJson(json),
];

/// 프로필 시간대 벽시계(UTC 그릇) 2026-10-13 [hour]:[minute].
DateTime _at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 10, 13, hour, minute);

void main() {
  test('08:00이면 다음 09:07(외 2개)', () {
    expect(
      summarizeTodaySchedules(_today(), now: _at(8)),
      const TodayScheduleHighlight(
        status: TodayScheduleStatus.next,
        time: '09:07',
        title: '팀 주간 회의',
        moreCount: 2,
      ),
    );
  });

  test('10:00이면 다음 19:00(외 2개)', () {
    expect(
      summarizeTodaySchedules(_today(), now: _at(10)),
      const TodayScheduleHighlight(
        status: TodayScheduleStatus.next,
        time: '19:00',
        title: '요가 수업',
        moreCount: 2,
      ),
    );
  });

  test('같은 분의 일정은 아직 다음이다(09:07에 09:07)', () {
    expect(
      summarizeTodaySchedules(_today(), now: _at(9, 7)),
      isA<TodayScheduleHighlight>().having((s) => s.time, 'time', '09:07'),
    );
    expect(
      summarizeTodaySchedules(_today(), now: _at(9, 8)),
      isA<TodayScheduleHighlight>().having((s) => s.time, 'time', '19:00'),
    );
  });

  test('20:00이면 하루 종일 일정이 진행 중(외 2개)', () {
    expect(
      summarizeTodaySchedules(_today(), now: _at(20)),
      const TodayScheduleHighlight(
        status: TodayScheduleStatus.inProgress,
        time: null,
        title: '엄마 생신',
        moreCount: 2,
      ),
    );
  });

  test('하루 종일 없이 모두 지났으면 개수 문장 재료', () {
    expect(
      summarizeTodaySchedules(_today(withAllDay: false), now: _at(20)),
      const TodayScheduleAllPast(count: 2),
    );
  });

  test('일정이 없으면 null', () {
    expect(summarizeTodaySchedules(const [], now: _at(8)), isNull);
  });

  test('일정 하나면 외 0개', () {
    final only = _today().where((s) => s.id == 'evening').toList();
    expect(
      summarizeTodaySchedules(only, now: _at(8)),
      isA<TodayScheduleHighlight>().having((s) => s.moreCount, 'more', 0),
    );
  });
}
