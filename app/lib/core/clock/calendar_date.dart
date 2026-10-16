import 'package:flutter/foundation.dart';

/// 시간대 없는 달력 날짜(연·월·일).
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  /// [year], [month], [day]로 날짜를 만듭니다. 없는 날짜면 [ArgumentError]입니다.
  new(this.year, this.month, this.day) {
    if (!_exists(year, month, day)) {
      throw ArgumentError('없는 날짜입니다: $year-$month-$day');
    }
  }

  /// `YYYY-MM-DD` 문자열을 읽습니다. 형식이 틀리거나 없는 날짜면
  /// [FormatException]입니다.
  factory parse(String source) {
    final match = _pattern.firstMatch(source);
    if (match == null) {
      throw FormatException('YYYY-MM-DD 형식이어야 합니다.', source);
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (!_exists(year, month, day)) {
      throw FormatException('없는 날짜입니다.', source);
    }
    return CalendarDate(year, month, day);
  }

  static bool _exists(int year, int month, int day) {
    final check = DateTime.utc(year, month, day);
    return check.year == year && check.month == month && check.day == day;
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// 연.
  final int year;

  /// 월(1~12).
  final int month;

  /// 일(1~31).
  final int day;

  /// 이 날짜에서 [days]일 뒤(음수면 앞) 날짜. 날짜 계산은 UTC로만 하므로 시간대와
  /// 섞이지 않습니다.
  CalendarDate addDays(int days) {
    final moved = DateTime.utc(year, month, day + days);
    return CalendarDate(moved.year, moved.month, moved.day);
  }

  /// 요일(1=월 … 7=일, [DateTime.weekday]와 같음).
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// 이 날짜가 속한 달의 1일.
  CalendarDate get firstOfMonth => CalendarDate(year, month, 1);

  /// 이 날짜가 속한 달의 일수.
  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// 달력의 한 달(연·월). 일요일 시작 6주 42칸 격자를 계산합니다.
@immutable
final class CalendarMonth {
  /// [year]년 [month]월. [month]는 1~12여야 합니다(개발 중 `assert`로 검사합니다).
  const new(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'month는 1~12여야 합니다.');

  /// [date]가 속한 달.
  factory of(CalendarDate date) => CalendarMonth(date.year, date.month);

  /// 지원하는 첫 달(1900-01)과 마지막 달(2099-12).
  static const _firstYear = 1900;
  static const _lastYear = 2099;

  /// 연.
  final int year;

  /// 월(1~12).
  final int month;

  /// 다음 달.
  CalendarMonth next() =>
      month == 12 ? CalendarMonth(year + 1, 1) : CalendarMonth(year, month + 1);

  /// 이전 달.
  CalendarMonth previous() =>
      month == 1 ? CalendarMonth(year - 1, 12) : CalendarMonth(year, month - 1);

  /// 지원 범위(1900-01 ~ 2099-12) 안인지.
  bool get isSupported => year >= _firstYear && year <= _lastYear;

  /// 격자 첫 칸. 이 달 1일이 속한 주의 일요일입니다.
  CalendarDate get gridStart {
    final first = CalendarDate(year, month, 1);
    return first.addDays(-(first.weekday % 7));
  }

  /// 격자 마지막 칸(42번째 칸).
  CalendarDate get gridEnd => gridStart.addDays(_gridCellCount - 1);

  /// 일요일 시작 6주 42칸.
  List<CalendarDate> get gridDays {
    final start = gridStart;
    return List<CalendarDate>.generate(_gridCellCount, start.addDays);
  }

  static const _gridCellCount = 42;

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
