/// Patrol 흐름이 "오늘"에서 날짜를 계산하는 순수 함수입니다(#781).
///
/// fake 모드는 시나리오의 고정 오늘(2026-10-13), staging 모드는 기기의 실제 오늘이라 달 말일,
/// 1일, 연말에도 맞아야 합니다. 단위 테스트(`test/patrol_support/`)가 읽을 수 있게
/// `package:patrol`을 import하지 않습니다.
library;

import 'package:myungli_diary/core/clock/calendar_date.dart';

/// [today]의 다음 달 [day]일입니다. 달력 흐름이 일정을 넣었다가 지울 날로 씁니다.
///
/// [day]는 모든 달에 있는 날(1~28)이어야 합니다. 15일이면 [today]가 든 달의 격자(최대 다음 달 7일까지)
/// 밖이라 다음 달 격자에만 보입니다.
CalendarDate dayOfNextMonth(CalendarDate today, {int day = 15}) {
  assert(day >= 1 && day <= 28, 'day는 모든 달에 있는 1~28이어야 합니다: $day');
  final next = CalendarMonth.of(today).next();
  return CalendarDate(next.year, next.month, day);
}

/// [today]보다 [days]일 앞 날짜입니다. 일기 흐름이 쓸 날로 씁니다.
CalendarDate daysBefore(CalendarDate today, int days) {
  assert(days >= 0, 'days는 0 이상이어야 합니다: $days');
  return today.addDays(-days);
}

/// 날짜 고르기가 [today]가 든 달에서 열릴 때, [target]이 든 달까지 "이전 달"을 눌러야 하는 횟수입니다.
/// 같은 달이면 0입니다. [target]이 [today]보다 뒤이면 [ArgumentError]입니다(날짜 고르기는 미래 달로
/// 넘기지 않습니다).
int previousMonthTaps(CalendarDate today, CalendarDate target) {
  final taps = (today.year - target.year) * 12 + (today.month - target.month);
  if (taps < 0) {
    throw ArgumentError.value(target, 'target', '$today보다 뒤 달은 고를 수 없습니다');
  }
  return taps;
}
