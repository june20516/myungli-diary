import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

import '../../patrol_test/support/e2e_dates.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  group('dayOfNextMonth', () {
    test('달 중간, 말일, 1일, 연말 모두 다음 달 15일입니다', () {
      expect(
        dayOfNextMonth(CalendarDate(2026, 10, 13)),
        CalendarDate(2026, 11, 15),
      );
      expect(
        dayOfNextMonth(CalendarDate(2026, 1, 31)),
        CalendarDate(2026, 2, 15),
      );
      expect(
        dayOfNextMonth(CalendarDate(2026, 11, 1)),
        CalendarDate(2026, 12, 15),
      );
      expect(
        dayOfNextMonth(CalendarDate(2026, 12, 31)),
        CalendarDate(2027, 1, 15),
      );
    });
  });

  group('daysBefore', () {
    test('지난 달과 지난 해로 넘어갑니다', () {
      expect(
        daysBefore(CalendarDate(2026, 10, 13), 3),
        CalendarDate(2026, 10, 10),
      );
      expect(
        daysBefore(CalendarDate(2026, 11, 2), 3),
        CalendarDate(2026, 10, 30),
      );
      expect(
        daysBefore(CalendarDate(2027, 1, 1), 3),
        CalendarDate(2026, 12, 29),
      );
      expect(
        daysBefore(CalendarDate(2028, 3, 2), 3),
        CalendarDate(2028, 2, 28),
      );
    });
  });

  group('previousMonthTaps', () {
    test('같은 달이면 0, 지난 달이면 1', () {
      final today = CalendarDate(2026, 10, 13);
      expect(previousMonthTaps(today, daysBefore(today, 3)), 0);
      final first = CalendarDate(2026, 11, 2);
      expect(previousMonthTaps(first, daysBefore(first, 3)), 1);
      final newYear = CalendarDate(2027, 1, 1);
      expect(previousMonthTaps(newYear, daysBefore(newYear, 3)), 1);
    });

    test('미래 달은 ArgumentError', () {
      expect(
        () => previousMonthTaps(
          CalendarDate(2026, 10, 13),
          CalendarDate(2026, 11, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  test('pickDateLabel은 앱의 확인 버튼 문구와 같은 형식입니다', () {
    expect(pickDateLabel(CalendarDate(2026, 10, 10), 'ko_KR'), '10월 10일');
  });
}
