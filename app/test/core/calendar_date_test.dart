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
      const month = CalendarMonth(2026, 10);
      expect(month.gridStart, CalendarDate(2026, 9, 27));
      expect(month.gridEnd, CalendarDate(2026, 11, 7));
      expect(month.gridDays, hasLength(42));
    });

    test('격자 첫 칸은 항상 일요일이다', () {
      expect(
        const CalendarMonth(2026, 2).gridDays.first.weekday,
        DateTime.sunday,
      );
      expect(
        const CalendarMonth(2026, 11).gridDays.first.weekday,
        DateTime.sunday,
      );
    });

    test('지원 범위는 1900-01 ~ 2099-12다', () {
      expect(const CalendarMonth(1900, 1).isSupported, isTrue);
      expect(const CalendarMonth(1900, 1).previous().isSupported, isFalse);
      expect(const CalendarMonth(2099, 12).isSupported, isTrue);
      expect(const CalendarMonth(2099, 12).next().isSupported, isFalse);
    });

    test('supportedGridStart·End는 격자를 지원 날짜 범위로 자릅니다', () {
      const first = CalendarMonth(1900, 1);
      expect(first.gridStart.isSupported, isFalse);
      expect(first.supportedGridStart, CalendarDate.supportedFirst);
      expect(first.supportedGridEnd, first.gridEnd);
      const last = CalendarMonth(2099, 12);
      expect(last.gridEnd.isSupported, isFalse);
      expect(last.supportedGridStart, last.gridStart);
      expect(last.supportedGridEnd, CalendarDate.supportedLast);
      const october = CalendarMonth(2026, 10);
      expect(october.supportedGridStart, october.gridStart);
      expect(october.supportedGridEnd, october.gridEnd);
    });

    test('next·previous는 해를 넘긴다', () {
      expect(
        const CalendarMonth(2026, 12).next(),
        const CalendarMonth(2027, 1),
      );
      expect(
        const CalendarMonth(2026, 1).previous(),
        const CalendarMonth(2025, 12),
      );
    });

    test('of, 동등성, toString', () {
      expect(
        CalendarMonth.of(CalendarDate(2026, 10, 16)),
        const CalendarMonth(2026, 10),
      );
      expect(
        const CalendarMonth(2026, 10).hashCode,
        const CalendarMonth(2026, 10).hashCode,
      );
      expect(const CalendarMonth(2026, 3).toString(), '2026-03');
      expect(() => CalendarMonth(2026, 13), throwsA(isA<AssertionError>()));
    });
  });

  group('CalendarDate 지원 범위(D41)', () {
    test('양력 1900-01-31 ~ 2099-12-31만 지원합니다', () {
      expect(CalendarDate.supportedFirst, CalendarDate(1900, 1, 31));
      expect(CalendarDate.supportedLast, CalendarDate(2099, 12, 31));
      expect(CalendarDate(1900, 1, 30).isSupported, isFalse);
      expect(CalendarDate(1899, 12, 31).isSupported, isFalse);
      expect(CalendarDate(1900, 1, 31).isSupported, isTrue);
      expect(CalendarDate(2099, 12, 31).isSupported, isTrue);
      expect(CalendarDate(2100, 1, 1).isSupported, isFalse);
    });

    test('달 지원 범위는 날짜 경계를 담은 달까지입니다', () {
      expect(const CalendarMonth(1899, 12).isSupported, isFalse);
      expect(const CalendarMonth(1900, 1).isSupported, isTrue);
      expect(const CalendarMonth(2100, 1).isSupported, isFalse);
    });
  });
}
