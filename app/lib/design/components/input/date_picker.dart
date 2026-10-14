import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/wheel.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 날짜 기준(양력·음력).
enum BirthCalendar {
  /// 양력.
  solar,

  /// 음력(KASI 한국 음력).
  lunar,
}

/// 생일 입력값. 달력 종류와 년·월·일, 음력 윤달 여부입니다.
///
/// 양력 ↔ 음력 변환과 윤달이 실제로 있는지는 여기서 판단하지 않습니다(server 422).
@immutable
final class BirthDateValue {
  /// 값을 만듭니다. [isLeapMonth]는 음력일 때만 뜻이 있습니다.
  const new({
    required this.calendar,
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
  });

  /// 휠이 보이는 첫 해.
  static const int minYear = 1900;

  /// 휠이 보이는 마지막 해.
  static const int maxYear = 2099;

  /// 달력 종류.
  final BirthCalendar calendar;

  /// 년.
  final int year;

  /// 월(1~12).
  final int month;

  /// 일.
  final int day;

  /// 음력 윤달 여부.
  final bool isLeapMonth;

  /// 이 값의 달에 있을 수 있는 가장 큰 일. 양력은 그달 실제 날수, 음력은 30입니다.
  int get maxDay => calendar == BirthCalendar.lunar
      ? 30
      : DateTime.utc(year, month + 1, 0).day;

  /// 지원 범위(D41) 안인지.
  ///
  /// 양력은 1900-01-31 ~ 2099-12-31을 날짜까지 판정하고, 없는 날(2월 30일 등)은 밖입니다.
  /// 음력은 연도 범위만 보고 나머지는 server 422가 판정합니다.
  bool get isWithinSupportedRange {
    if (year < minYear || year > maxYear) return false;
    if (calendar == BirthCalendar.lunar) return true;
    if (month < 1 || month > 12 || day < 1 || day > maxDay) return false;
    // 1900년 1월은 31일부터입니다.
    return !(year == minYear && month == 1 && day < 31);
  }

  /// 일부 칸만 바꾼 값.
  BirthDateValue copyWith({
    BirthCalendar? calendar,
    int? year,
    int? month,
    int? day,
    bool? isLeapMonth,
  }) => BirthDateValue(
    calendar: calendar ?? this.calendar,
    year: year ?? this.year,
    month: month ?? this.month,
    day: day ?? this.day,
    isLeapMonth: isLeapMonth ?? this.isLeapMonth,
  );

  @override
  bool operator ==(Object other) =>
      other is BirthDateValue &&
      other.calendar == calendar &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => Object.hash(calendar, year, month, day, isLeapMonth);

  @override
  String toString() =>
      'BirthDateValue(${calendar.name} $year-$month-$day'
      '${isLeapMonth ? ' 윤달' : ''})';
}

/// `date-picker` 변형.
enum DatePickerVariant {
  /// 생일 입력.
  birth,

  /// 일기 목록에서 날짜로 가기(시트 안). 계획 5에서 구현합니다.
  calendar,
}

/// 생일 입력 휠(`date-picker` `birth`).
///
/// 양력·음력을 [Segmented]로 고르고 년(1900~2099)·월·일 휠을 돌립니다. 양력이면 일 휠이
/// 그달의 실제 날수까지, 음력이면 30일까지입니다. 달이나 해를 바꿔 날수가 모자라면 일을 그달
/// 끝으로 맞춥니다. 음력일 때만 윤달 체크([CheckRow] inline)를 보이고, 양력으로 바꾸면
/// 윤달 표시가 꺼집니다. 음력 날짜의 양력 확인 줄과 월 휠의 '윤N월' 항목은 그리지 않습니다
/// (결정 A20 ④: 변환·윤달 유무 API가 없어 server 422로 받습니다).
///
/// [variant]가 [DatePickerVariant.calendar]이면 아직 구현 전이라 [UnimplementedError]입니다.
class BirthDatePicker extends StatelessWidget {
  /// 생일 휠을 만듭니다. 글자(양력·음력·윤달)는 화면이 줍니다.
  const new({
    required this.value,
    required this.onChanged,
    required this.calendarLabelSolar,
    required this.calendarLabelLunar,
    required this.leapMonthLabel,
    this.variant = DatePickerVariant.birth,
    this.identifier,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'date-picker',
    {'birth', 'calendar'},
    {'wheelTick', 'out-of-range'},
  );

  /// 년 휠을 찾는 테스트용 키.
  static const Key yearWheelKey = ValueKey('date-picker-year');

  /// 월 휠을 찾는 테스트용 키.
  static const Key monthWheelKey = ValueKey('date-picker-month');

  /// 일 휠을 찾는 테스트용 키.
  static const Key dayWheelKey = ValueKey('date-picker-day');

  /// 변형.
  final DatePickerVariant variant;

  /// 지금 값.
  final BirthDateValue value;

  /// 값이 바뀔 때(휠, 양력·음력, 윤달).
  final ValueChanged<BirthDateValue> onChanged;

  /// 양력 항목 글자.
  final String calendarLabelSolar;

  /// 음력 항목 글자.
  final String calendarLabelLunar;

  /// 윤달 체크 글자.
  final String leapMonthLabel;

  /// 양력·음력 선택의 IA 슬롯 id.
  final String? identifier;

  void _setDate({int? year, int? month, int? day}) {
    final next = value.copyWith(year: year, month: month, day: day);
    onChanged(next.copyWith(day: math.min(next.day, next.maxDay)));
  }

  void _setCalendar(BirthCalendar calendar) {
    final next = value.copyWith(
      calendar: calendar,
      // 윤달은 음력에만 있습니다.
      isLeapMonth: calendar == BirthCalendar.lunar && value.isLeapMonth,
    );
    onChanged(next.copyWith(day: math.min(next.day, next.maxDay)));
  }

  @override
  Widget build(BuildContext context) {
    if (variant == DatePickerVariant.calendar) {
      throw UnimplementedError('date-picker calendar 변형은 계획 5에서 구현합니다.');
    }
    final l10n = AppLocalizations.of(context);
    final lunar = value.calendar == BirthCalendar.lunar;
    const years = BirthDateValue.maxYear - BirthDateValue.minYear + 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<BirthCalendar>(
          label: '$calendarLabelSolar $calendarLabelLunar',
          identifier: identifier,
          items: [
            SegmentedItem(BirthCalendar.solar, calendarLabelSolar),
            SegmentedItem(BirthCalendar.lunar, calendarLabelLunar),
          ],
          selected: value.calendar,
          onChanged: _setCalendar,
        ),
        const SizedBox(height: Space.s12),
        WheelGroup(
          wheels: [
            Wheel(
              key: yearWheelKey,
              flex: 3,
              itemCount: years,
              selectedIndex: value.year - BirthDateValue.minYear,
              itemLabel: (i) =>
                  l10n.datePickerYearItem(BirthDateValue.minYear + i),
              onSelectedIndexChanged: (i) =>
                  _setDate(year: BirthDateValue.minYear + i),
              semanticLabel: l10n.datePickerYearLabel,
            ),
            Wheel(
              key: monthWheelKey,
              flex: 2,
              itemCount: 12,
              selectedIndex: value.month - 1,
              itemLabel: (i) => l10n.datePickerMonthItem(i + 1),
              onSelectedIndexChanged: (i) => _setDate(month: i + 1),
              semanticLabel: l10n.datePickerMonthLabel,
            ),
            Wheel(
              key: dayWheelKey,
              flex: 2,
              itemCount: value.maxDay,
              selectedIndex: value.day - 1,
              itemLabel: (i) => l10n.datePickerDayItem(i + 1),
              onSelectedIndexChanged: (i) => _setDate(day: i + 1),
              semanticLabel: l10n.datePickerDayLabel,
            ),
          ],
        ),
        if (lunar)
          CheckRow(
            variant: CheckRowVariant.inline,
            label: leapMonthLabel,
            checked: value.isLeapMonth,
            onChanged: (checked) =>
                onChanged(value.copyWith(isLeapMonth: checked)),
          ),
      ],
    );
  }
}
