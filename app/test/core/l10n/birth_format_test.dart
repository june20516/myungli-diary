import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/l10n/birth_format.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';

void main() {
  final ko = AppLocalizationsKo();

  group('birthCalendarTag(출생 정보 줄 달력 꼬리표)', () {
    test('양력은 "양력", 음력은 "음력"', () {
      expect(
        birthCalendarTag(ko, calendar: CalendarType.solar, isLeapMonth: false),
        '양력',
      );
      expect(
        birthCalendarTag(ko, calendar: CalendarType.lunar, isLeapMonth: false),
        '음력',
      );
    });

    test('음력 윤달은 "음력 윤달"', () {
      expect(
        birthCalendarTag(ko, calendar: CalendarType.lunar, isLeapMonth: true),
        '음력 윤달',
      );
    });

    test('양력이면 윤달 표시가 와도 "양력"', () {
      expect(
        birthCalendarTag(ko, calendar: CalendarType.solar, isLeapMonth: true),
        '양력',
      );
    });
  });

  test('formatBirthDayNumeric은 날 숫자를 그대로 넣습니다(음력 2월 30일)', () async {
    await initializeDateFormatting('ko');
    expect(formatBirthDayNumeric('ko', 1990, 2, 30), contains('30'));
  });
}
