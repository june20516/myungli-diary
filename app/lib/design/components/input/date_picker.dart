import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/input/month_date_picker.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/wheel.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
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
/// 양력 ↔ 음력 변환과 윤달이 실제로 있는지는 여기서 판단하지 않습니다. 화면이
/// `convertLunarDate`로 물어 [BirthDatePicker.leapMonth]와
/// [BirthDatePicker.solarConfirm]을 줍니다.
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
      '${isLeapMonth ? ' leap' : ''})';
}

/// `date-picker` 변형.
enum DatePickerVariant {
  /// 생일 입력.
  birth,

  /// 일정 날짜(양력만). `birth`에서 양력·음력 선택과 윤달 줄을 뺀 모양입니다.
  solar,

  /// 일기 목록에서 날짜로 가기(시트 안). 휠이 아니라 달력 격자라 [MonthDatePicker]가
  /// 그립니다.
  calendar,
}

/// 음력 확인 줄(`solarConfirm`)에 보일 것. 화면이 `convertLunarDate`로 물어 정합니다.
@immutable
final class SolarConfirm {
  /// 조회 중. 확인 줄 자리에 skeleton 한 줄을 둡니다.
  const new loading() : text = null;

  /// 확인 줄 글자(양력으로 바꾼 날짜, 또는 조회 실패 문구).
  const new text(String this.text);

  /// 보일 글자. 조회 중이면 null입니다.
  final String? text;

  /// 조회 중인지.
  bool get loading => text == null;
}

/// 생일 입력 휠(`date-picker` `birth`).
///
/// 양력·음력을 [Segmented]로 고르고 년(1900~2099)·월·일 휠을 돌립니다. 양력이면 일 휠이
/// 그달의 실제 날수까지, 음력이면 30일까지입니다. 달이나 해를 바꿔 날수가 모자라면 일을 그달
/// 끝으로 맞춥니다.
///
/// 음력이면 V31 목표 모양입니다. [leapMonth](그해 윤달이 든 달)가 있으면 월 휠의 그 달 바로
/// 다음에 '윤N월'(`datePickerLeapMonthValue`)을 끼우고, 휠 아래에 양력 확인 줄
/// ([solarConfirm], `type.caption.lg` `color.text.secondary`, 글자가 바뀌면
/// `appear.seep`)을 둡니다. 윤달이 있는지와
/// 양력 날짜는 화면이 `convertLunarDate`로 물어 줍니다(A20 ④). 고른 달이 [leapMonth]가 아니면
/// 받은 값의 윤달 표시는 보지 않습니다. 양력으로 바꾸면 윤달 표시가 꺼집니다.
///
/// [DatePickerVariant.solar]는 양력·음력 선택과 윤달·확인 줄을 그리지 않고, 받은 값이 음력이어도
/// 양력으로 보고 늘 양력 값만 돌려줍니다(일정 날짜). 휠·선택 띠·범위는 `birth`와 같습니다.
///
/// [DatePickerVariant.calendar]는 휠이 아니라 [MonthDatePicker]입니다. 이 위젯에 주면
/// [ArgumentError]입니다.
class BirthDatePicker extends StatelessWidget {
  /// 생일 휠을 만듭니다. 글자(양력·음력)는 화면이 줍니다.
  const new({
    required this.value,
    required this.onChanged,
    required this.calendarLabelSolar,
    required this.calendarLabelLunar,
    this.leapMonth,
    this.solarConfirm,
    this.variant = DatePickerVariant.birth,
    this.identifier,
    super.key,
  }) : assert(
         leapMonth == null || (leapMonth >= 1 && leapMonth <= 12),
         '윤달이 든 달은 1~12입니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'date-picker',
    {'birth', 'solar', 'calendar'},
    {'wheelTick', 'out-of-range'},
  );

  /// 년 휠을 찾는 테스트용 키.
  static const Key yearWheelKey = ValueKey('date-picker-year');

  /// 월 휠을 찾는 테스트용 키.
  static const Key monthWheelKey = ValueKey('date-picker-month');

  /// 일 휠을 찾는 테스트용 키.
  static const Key dayWheelKey = ValueKey('date-picker-day');

  /// 양력 확인 줄을 찾는 테스트용 키.
  static const Key solarConfirmKey = ValueKey('date-picker-solar-confirm');

  /// 변형.
  final DatePickerVariant variant;

  /// 지금 값.
  final BirthDateValue value;

  /// 값이 바뀔 때(휠, 양력·음력).
  final ValueChanged<BirthDateValue> onChanged;

  /// 양력 항목 글자.
  final String calendarLabelSolar;

  /// 음력 항목 글자.
  final String calendarLabelLunar;

  /// 음력일 때 그해 윤달이 든 달(1~12). 모르거나 없으면 null이고 월 휠은 12칸입니다.
  final int? leapMonth;

  /// 음력일 때 휠 아래 확인 줄. null이면 그리지 않습니다.
  final SolarConfirm? solarConfirm;

  /// 음력을 고를 수 있는 변형인지(`birth`만).
  bool get _lunarAllowed => variant == DatePickerVariant.birth;

  /// 양력·음력 선택의 IA 슬롯 id.
  final String? identifier;

  /// 윤달이 [leapMonth] 다음에 끼워진 월 휠의 [index]번째 칸이 가리키는 (달, 윤달 여부).
  static ({int month, bool leap}) monthAt(int index, int? leapMonth) {
    if (leapMonth == null || index < leapMonth) {
      return (month: index + 1, leap: false);
    }
    if (index == leapMonth) return (month: leapMonth, leap: true);
    return (month: index, leap: false);
  }

  /// [monthAt]의 반대: [month](윤달이면 [leap])가 놓인 월 휠 칸 자리.
  static int monthIndexOf(int month, {required bool leap, int? leapMonth}) {
    if (leapMonth == null || month < leapMonth) return month - 1;
    if (month == leapMonth) return leap ? leapMonth : leapMonth - 1;
    return month;
  }

  /// [_lunarAllowed]가 false면 양력·윤달 아님으로 고정하고, 일을 그달 양력 날수에 맞춘 값입니다.
  BirthDateValue get _effectiveValue {
    if (_lunarAllowed) return value;
    final solar = value.copyWith(
      calendar: BirthCalendar.solar,
      isLeapMonth: false,
    );
    return solar.copyWith(day: math.min(solar.day, solar.maxDay));
  }

  /// 음력이고 그해 윤달 칸이 있을 때의 윤달 칸 자리 기준 달. 그 밖은 null입니다.
  int? get _shownLeapMonth =>
      _lunarAllowed && value.calendar == BirthCalendar.lunar ? leapMonth : null;

  void _setDate({int? year, int? month, int? day, bool? leap}) {
    final next = _effectiveValue.copyWith(
      year: year,
      month: month,
      day: day,
      isLeapMonth: leap,
    );
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
      throw ArgumentError.value(
        variant,
        'variant',
        'date-picker calendar 변형은 MonthDatePicker입니다.',
      );
    }
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final value = _effectiveValue;
    final lunar = value.calendar == BirthCalendar.lunar;
    final leapMonth = _shownLeapMonth;
    // 고른 달이 윤달 칸이 아니면 받은 윤달 표시는 보지 않습니다(해를 바꿔 윤달이 없어진 경우 등).
    final onLeap = lunar && value.isLeapMonth && value.month == leapMonth;
    final confirm = lunar ? solarConfirm : null;
    const years = BirthDateValue.maxYear - BirthDateValue.minYear + 1;
    final confirmStyle = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
    );

    String monthLabel(int i) {
      final at = monthAt(i, leapMonth);
      return at.leap
          ? l10n.datePickerLeapMonthValue(at.month)
          : l10n.datePickerMonthItem(at.month);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lunarAllowed) ...[
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
        ],
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
              itemCount: leapMonth == null ? 12 : 13,
              selectedIndex: monthIndexOf(
                value.month,
                leap: onLeap,
                leapMonth: leapMonth,
              ),
              // 윤달 칸은 '윤N월'로 보이고 그대로 읽습니다.
              itemLabel: monthLabel,
              onSelectedIndexChanged: (i) {
                final at = monthAt(i, leapMonth);
                _setDate(month: at.month, leap: lunar && at.leap);
              },
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
        if (confirm != null)
          Padding(
            key: solarConfirmKey,
            padding: const EdgeInsets.only(top: Space.s8),
            child: confirm.loading
                ? SkeletonBlock(lines: 1, lineStyle: confirmStyle)
                : SeepPresence(
                    // 글자가 바뀔 때마다 새로 스밉니다.
                    key: ValueKey(confirm.text),
                    present: true,
                    child: Text(confirm.text!, style: confirmStyle),
                  ),
          ),
      ],
    );
  }
}
