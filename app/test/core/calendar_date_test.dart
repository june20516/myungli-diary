import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

void main() {
  group('CalendarDate 계산', () {
    test('addDays는 윤일과 해 경계를 넘고 음수는 반대 방향이다', () {
      expect(CalendarDate(2024, 2, 28).addDays(1), CalendarDate(2024, 2, 29));
      expect(CalendarDate(2026, 12, 31).addDays(1), CalendarDate(2027, 1, 1));
      expect(CalendarDate(2027, 1, 1).addDays(-1), CalendarDate(2026, 12, 31));
      expect(CalendarDate(2024, 3, 1).addDays(-1), CalendarDate(2024, 2, 29));
    });

    test('weekday는 1=월 … 7=일이다', () {
      expect(CalendarDate(2026, 10, 16).weekday, DateTime.friday);
      expect(CalendarDate(2026, 10, 18).weekday, DateTime.sunday);
    });

    test('firstOfMonth와 daysInMonth', () {
      expect(
        CalendarDate(2026, 10, 16).firstOfMonth,
        CalendarDate(2026, 10, 1),
      );
      expect(CalendarDate(2024, 2, 10).daysInMonth, 29);
      expect(CalendarDate(2026, 2, 10).daysInMonth, 28);
      expect(CalendarDate(2026, 12, 1).daysInMonth, 31);
    });
  });

  group('CalendarMonth', () {
    test('2026-10 격자는 9/27 일요일부터 11/7까지 42칸이다', () {
      final month = CalendarMonth(2026, 10);
      expect(month.gridStart, CalendarDate(2026, 9, 27));
      expect(month.gridEnd, CalendarDate(2026, 11, 7));
      expect(month.gridDays, hasLength(42));
    });

    test('격자 첫 칸은 항상 일요일이다', () {
      expect(CalendarMonth(2026, 2).gridDays.first.weekday, DateTime.sunday);
      expect(CalendarMonth(2026, 11).gridDays.first.weekday, DateTime.sunday);
    });

    test('지원 범위는 1900-01 ~ 2099-12다', () {
      expect(CalendarMonth(1900, 1).isSupported, isTrue);
      expect(CalendarMonth(1900, 1).previous().isSupported, isFalse);
      expect(CalendarMonth(2099, 12).isSupported, isTrue);
      expect(CalendarMonth(2099, 12).next().isSupported, isFalse);
    });

    test('next·previous는 해를 넘긴다', () {
      expect(CalendarMonth(2026, 12).next(), CalendarMonth(2027, 1));
      expect(CalendarMonth(2026, 1).previous(), CalendarMonth(2025, 12));
    });

    test('of, 동등성, toString', () {
      expect(
        CalendarMonth.of(CalendarDate(2026, 10, 16)),
        CalendarMonth(2026, 10),
      );
      expect(
        CalendarMonth(2026, 10).hashCode,
        CalendarMonth(2026, 10).hashCode,
      );
      expect(CalendarMonth(2026, 3).toString(), '2026-03');
      expect(() => CalendarMonth(2026, 13), throwsArgumentError);
    });
  });
}
