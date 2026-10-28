import 'package:intl/intl.dart';

/// [locale]의 연월일 모양(`yMMMMd`, 예 "1990년 5월 15일")으로 쓰되, 날 칸은 [day] 숫자를
/// 그대로 넣습니다.
///
/// 음력 날은 양력 달력에 없는 날(2월 30일)일 수 있어 날짜 계산 없이 날 숫자를 씁니다.
String formatBirthDay(String locale, int year, int month, int day) {
  final pattern = DateFormat.yMMMMd(locale).pattern!;
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < pattern.length; i++) {
    final char = pattern[i];
    if (char == "'") {
      quoted = !quoted;
      buffer.write(char);
    } else if (!quoted && char == 'd') {
      // 날 칸(d, dd)을 글자 그대로의 숫자로 바꿉니다.
      while (i + 1 < pattern.length && pattern[i + 1] == 'd') {
        i++;
      }
      buffer.write("'$day'");
    } else {
      buffer.write(char);
    }
  }
  return DateFormat(buffer.toString(), locale).format(DateTime(year, month));
}

/// 태어난 시각 `HH:mm`([value])을 [locale]의 시각(예 "오후 2:30")으로 씁니다. 형식이 맞지
/// 않으면 받은 값 그대로입니다.
String formatBirthClock(String locale, String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first);
  final minute = parts.length == 2 ? int.tryParse(parts.last) : null;
  if (hour == null || minute == null) return value;
  return DateFormat.jm(locale).format(DateTime(2000, 1, 1, hour, minute));
}
