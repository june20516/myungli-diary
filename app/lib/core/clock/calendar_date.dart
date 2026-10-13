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
