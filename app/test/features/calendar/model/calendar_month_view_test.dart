import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/luck_level.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/calendar/model/calendar_month_view.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

/// member 시나리오의 2026년 10월 응답.
Calendar _october() {
  final fixture = jsonDecode(
    File('fixtures/member/getCalendar__2026-10.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Calendar.fromJson(fixture['body'] as Map<String, dynamic>);
}

CalendarDay _day(String date) =>
    _october().days.singleWhere((day) => day.date == date);

/// [day]의 음력을 바꾼 사본.
CalendarDay _withLunar(
  CalendarDay day, {
  required int month,
  required int dayOfMonth,
  bool isLeapMonth = false,
}) {
  final json = jsonDecode(jsonEncode(day.toJson())) as Map<String, dynamic>;
  json['lunar'] = {
    'month': month,
    'day': dayOfMonth,
    'isLeapMonth': isLeapMonth,
  };
  return CalendarDay.fromJson(json);
}

const _names = GlossaryNames({
  'solar_term': {'hallo': '한로', 'sanggang': '상강'},
});

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await initializeDateFormatting('ko');
    l10n = lookupAppLocalizations(const Locale('ko'));
  });

  CalendarDayView viewOf(
    CalendarDay day, {
    GlossaryNames? names = _names,
    bool diaryWritten = false,
    int eventCount = 0,
    bool isToday = false,
  }) => dayCellDataOf(
    day,
    l10n: l10n,
    locale: 'ko',
    names: names,
    diaryWritten: diaryWritten,
    eventCount: eventCount,
    isToday: isToday,
  );

  test('초하루는 M.1이고 굵지 않다(A40)', () {
    final view = viewOf(_day('2026-10-11'));

    expect(view.lunarText, '9.1');
    expect(view.lunarBold, isFalse);
  });

  test('그 밖의 날은 음력 일(日)만', () {
    final view = viewOf(_day('2026-10-13'));

    expect(view.lunarText, '3');
    expect(view.lunarBold, isFalse);
  });

  test('절기 날은 glossary 절기 이름을 굵게', () {
    final view = viewOf(_day('2026-10-08'));

    expect(view.lunarText, '한로');
    expect(view.lunarBold, isTrue);
    expect(view.semanticLabel, contains('한로'));
  });

  test('절기 이름을 모르면(glossary 없음) 음력 규칙으로 그린다', () {
    final view = viewOf(_day('2026-10-08'), names: null);

    expect(view.lunarText, '28');
    expect(view.lunarBold, isFalse);
    expect(view.semanticLabel, contains('음력 8월 28일'));
  });

  test('절기와 초하루가 겹치면 절기 이름이 앞선다', () {
    final view = viewOf(
      _withLunar(_day('2026-10-08'), month: 9, dayOfMonth: 1),
    );

    expect(view.lunarText, '한로');
    expect(view.lunarBold, isTrue);
  });

  test('윤달 초하루는 윤달 표지를 붙인 M.1이고 라벨에 윤달을 넣는다(A40, V38)', () {
    final view = viewOf(
      _withLunar(
        _day('2026-10-11'),
        month: 6,
        dayOfMonth: 1,
        isLeapMonth: true,
      ),
    );

    expect(view.lunarText, '윤6.1');
    expect(view.semanticLabel, '10월 11일 일요일, 음력 6월 1일, 윤달, 무난한 날');
  });

  test('윤달의 다른 날은 일(日)만이고 라벨에 윤달을 넣는다(V38)', () {
    final view = viewOf(
      _withLunar(
        _day('2026-10-11'),
        month: 6,
        dayOfMonth: 5,
        isLeapMonth: true,
      ),
    );

    expect(view.lunarText, '5');
    expect(view.semanticLabel, '10월 11일 일요일, 음력 6월 5일, 윤달, 무난한 날');
  });

  test('라벨은 날짜, 음력, 길흉 낱말(level.text), 일기, 일정, 오늘 순서(A39)', () {
    final view = viewOf(
      _day('2026-10-13'),
      diaryWritten: true,
      eventCount: 3,
      isToday: true,
    );

    expect(view.luck, LuckLevel.good);
    expect(
      view.semanticLabel,
      '10월 13일 화요일, 음력 9월 3일, 잘 풀리는 날, '
      '${l10n.dayCellDiaryWritten}, 일정 3개, 오늘',
    );
  });

  test('일기·일정·오늘이 없으면 라벨에서 빠진다', () {
    final view = viewOf(_day('2026-10-13'));

    expect(view.semanticLabel, '10월 13일 화요일, 음력 9월 3일, 잘 풀리는 날');
  });

  test('절기 날 라벨은 음력 대신 절기 이름', () {
    final view = viewOf(_day('2026-10-23'));

    expect(view.semanticLabel, '10월 23일 금요일, 상강, 무난한 날');
  });

  test('날짜와 길흉을 그대로 옮긴다', () {
    final day = _day('2026-10-01');
    final view = viewOf(day);

    expect(view.date.toIso(), '2026-10-01');
    expect(view.luck, day.luckLevel);
  });
}
