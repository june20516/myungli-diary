import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/features/schedule/model/schedule_draft.dart';

import '../../../support/schedule_test_server.dart';

Schedule _schedule(String id) =>
    Schedule.fromJson(memberSchedules().firstWhere((json) => json['id'] == id));

/// [original]을 그대로 옮긴 초안. 시각은 5분 휠이 아래로 맞춘 값(A36)입니다.
ScheduleDraft _draftOf(Schedule original, {String? shownTime}) => ScheduleDraft(
  date: CalendarDate.parse(original.date),
  allDay: original.allDay,
  time: shownTime ?? original.time,
  title: original.title,
  memo: original.memo ?? '',
);

void main() {
  test('toInput은 시각 일정에 time을, 하루 종일에는 time 없이 싣는다', () {
    final timed = ScheduleDraft(
      date: CalendarDate(2026, 10, 14),
      allDay: false,
      time: '08:30',
      title: '산책',
    );
    expect(timed.toInput().toJson(), {
      'date': '2026-10-14',
      'allDay': false,
      'time': '08:30',
      'title': '산책',
    });

    final allDay = ScheduleDraft(
      date: CalendarDate(2026, 10, 14),
      allDay: true,
      time: '08:30',
      title: '휴가',
      memo: '바다',
    );
    expect(allDay.toInput().toJson(), {
      'date': '2026-10-14',
      'allDay': true,
      'title': '휴가',
      'memo': '바다',
    });
  });

  test('A36: 시각을 건드리지 않으면 PATCH에 time이 없다(5분 아래 맞춤 값이어도)', () {
    final original = _schedule('morning');
    final draft = _draftOf(original, shownTime: '09:05').copyWith(title: '회고');

    expect(draft.patchFrom(original)!.toJson(), {'title': '회고'});
  });

  test('시각을 건드리면 time을 보낸다', () {
    final original = _schedule('morning');
    final draft = _draftOf(original).withTime('10:00');

    expect(draft.patchFrom(original)!.toJson(), {'time': '10:00'});
  });

  test('하루 종일에서 시각 일정으로 바꾸면 time이 함께 간다', () {
    final original = _schedule('all-day');
    final draft = _draftOf(original).copyWith(allDay: false).withTime('18:00');

    expect(draft.patchFrom(original)!.toJson(), {
      'allDay': false,
      'time': '18:00',
    });
  });

  test('시각 일정을 하루 종일로 바꾸면 time 없이 allDay만 보낸다', () {
    final original = _schedule('morning');
    final draft = _draftOf(original).copyWith(allDay: true);

    expect(draft.patchFrom(original)!.toJson(), {'allDay': true});
  });

  test('날짜·메모 변경을 보내고, 메모를 지우면 빈 문자열이다', () {
    final original = _schedule('morning');
    final draft = _draftOf(original)
        .copyWith(date: CalendarDate(2026, 10, 15), memo: '');

    expect(draft.patchFrom(original)!.toJson(), {
      'date': '2026-10-15',
      'memo': '',
    });
  });

  test('바뀐 것이 없으면 null', () {
    final original = _schedule('morning');
    expect(_draftOf(original).patchFrom(original), isNull);
  });

  test('시각 일정에 시각이 없거나 제목이 비면 저장할 수 없다', () {
    final noTime = ScheduleDraft(
      date: CalendarDate(2026, 10, 14),
      allDay: false,
      title: '산책',
    );
    expect(noTime.isSavable, isFalse);
    expect(noTime.toInput, throwsStateError);
    expect(() => noTime.patchFrom(_schedule('all-day')), throwsStateError);

    expect(noTime.copyWith(allDay: true).isSavable, isTrue);
    expect(noTime.withTime('08:00').isSavable, isTrue);
    expect(noTime.withTime('08:00').copyWith(title: '').isSavable, isFalse);
  });
}
