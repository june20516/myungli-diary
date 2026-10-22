import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 시트 안 날짜 고르기(`date-picker` `calendar`): 일기 목록의 "날짜 골라 쓰기".
///
/// 달력 격자는 `calendar-month`와 같은 표시(일기 쓴 날 옅은 도장, 오늘 윤곽, 선택 굵은 숫자 +
/// 밑줄)이고 길흉 칸 채우기와 음력만 뺍니다. 미래 날짜는 흐리게 막고, 오늘이 든 달 뒤로는
/// 넘기지 않습니다(D49). 아래 버튼 글자([confirmLabel])에는 고른 날짜가 들어갑니다.
///
/// 보이는 달([month])과 고른 날([selected])은 쓰는 쪽이 듭니다. 달을 넘기면
/// [onMonthChange]로 알리고, 쓰는 쪽은 그 달의 일기 날짜([markedDates])를 넘깁니다.
class MonthDatePicker extends StatelessWidget {
  /// 날짜 고르기를 만듭니다.
  const new({
    required this.month,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.onMonthChange,
    required this.confirmLabel,
    required this.onConfirm,
    this.markedDates = const {},
    this.confirmIdentifier,
    super.key,
  });

  /// 보이는 달.
  final CalendarMonth month;

  /// 고른 날.
  final CalendarDate selected;

  /// 오늘. 이 날 뒤는 고를 수 없습니다.
  final CalendarDate today;

  /// 일기를 쓴 날(옅은 도장).
  final Set<CalendarDate> markedDates;

  /// 날을 골랐을 때.
  final ValueChanged<CalendarDate> onSelect;

  /// 달을 넘겼을 때.
  final ValueChanged<CalendarMonth> onMonthChange;

  /// 아래 버튼 글자(고른 날짜가 든 문구).
  final String confirmLabel;

  /// 아래 버튼을 눌렀을 때. null이면 버튼이 꺼집니다(`disabled`, 예 고른 날 일기를 다 채움).
  final VoidCallback? onConfirm;

  /// 아래 버튼의 IA 슬롯 id(`diary-list.pick-date.confirm`).
  final String? confirmIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarMonthView(
          month: month,
          title: calendarMonthTitle(locale, month),
          weekdayLabels: calendarWeekdayLabels(locale),
          cellOf: (date) => _cellOf(date, l10n, locale),
          loading: false,
          today: today,
          selected: selected,
          onSelect: onSelect,
          onMonthChange: onMonthChange,
          isDateEnabled: (date) => date.compareTo(today) <= 0,
          lastMonth: CalendarMonth.of(today),
        ),
        const SizedBox(height: Space.s16),
        PrimaryButton(
          label: confirmLabel,
          onPressed: onConfirm,
          identifier: confirmIdentifier,
        ),
      ],
    );
  }

  DayCellData _cellOf(CalendarDate date, AppLocalizations l10n, String locale) {
    final written = markedDates.contains(date);
    final isToday = date == today;
    return DayCellData(
      date: date,
      diaryWritten: written,
      semanticLabel: [
        DateFormat.MMMMEEEEd(locale)
            .format(DateTime(date.year, date.month, date.day)),
        if (written) l10n.dayCellDiaryWritten,
        if (isToday) l10n.dayCellToday,
      ].join(l10n.a11yListSeparator),
    );
  }
}
