import 'package:intl/intl.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 일기 목록 날짜 고르기 확인 버튼 문구(`diaryListPickDateConfirm`)에 들어가는 날짜입니다.
///
/// [locale]은 `Localizations.localeOf(context).toString()` 값(예 `ko_KR`)입니다.
String diaryPickDateLabel(CalendarDate date, String locale) =>
    DateFormat.MMMd(locale).format(DateTime(date.year, date.month, date.day));
