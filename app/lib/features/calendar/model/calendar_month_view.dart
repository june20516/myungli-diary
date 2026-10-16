import 'package:flutter/foundation.dart' show immutable;
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/luck_level.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

/// 절기 이름을 담은 glossary 범주(`Glossary.values.solar_term.<kind>`).
const _solarTermCategory = 'solar_term';

/// 달력 칸 하나의 표시 재료. 화면과 컴포넌트에 묶이지 않은 값입니다.
///
/// 컴포넌트 값(`day-cell`)으로 옮기는 일은 화면 쪽이 합니다. 선택·달 밖 여부처럼 화면 상태에
/// 달린 값은 여기에 없습니다.
@immutable
final class CalendarDayView {
  /// 칸 재료를 만듭니다. 보통 [dayCellDataOf]로 만듭니다.
  const new({
    required this.date,
    required this.luck,
    required this.lunarText,
    required this.lunarBold,
    required this.semanticLabel,
  });

  /// 양력 날짜.
  final CalendarDate date;

  /// 길흉(칸 바탕 채움). 색만으로 전하지 않으므로 [semanticLabel]에 낱말이 들어갑니다.
  final LuckLevel luck;

  /// 숫자 아래 음력 글자: 절기 이름, 초하루 `M.1`, 그 밖에는 음력 일(日)(A40).
  final String lunarText;

  /// [lunarText]를 굵게 그리는지(절기 날).
  final bool lunarBold;

  /// 스크린리더 라벨. "날짜 요일, 음력 또는 절기, 길흉 낱말, 일기 씀, 일정 N개, 오늘" 순서입니다
  /// (명세 `day-cell.a11y.label`).
  final String semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is CalendarDayView &&
      other.date == date &&
      other.luck == luck &&
      other.lunarText == lunarText &&
      other.lunarBold == lunarBold &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode =>
      Object.hash(date, luck, lunarText, lunarBold, semanticLabel);
}

/// [day]로 칸 재료를 만듭니다(A39·A40).
///
/// * 음력 글자: 절기 날이고 [names]에 그 절기 이름이 있으면 이름을 굵게, 아니면 초하루는
///   `M.1`, 그 밖에는 일(日)만입니다. 절기와 초하루가 겹치면 절기가 앞섭니다. 윤달 초하루도
///   `M.1`로 보이고 라벨에만 윤달을 넣습니다. 절기 시각(`SolarTerm.at`)은 쓰지 않습니다.
/// * 라벨의 날짜·요일은 [locale]의 `DateFormat`(A38), 길흉 낱말은 server가 렌더한
///   `CalendarDay.level.text`입니다(A39). 일기([diaryWritten])·일정([eventCount])·오늘
///   ([isToday])은 해당할 때만 넣습니다.
///
/// [locale]의 날짜 서식 데이터가 불려 있어야 합니다. 앱에서는 `GlobalMaterialLocalizations`가
/// 불러 두고, 위젯 밖 테스트는 `initializeDateFormatting`으로 불러 둡니다.
CalendarDayView dayCellDataOf(
  CalendarDay day, {
  required AppLocalizations l10n,
  required String locale,
  required GlossaryNames? names,
  bool diaryWritten = false,
  int eventCount = 0,
  bool isToday = false,
}) {
  final date = CalendarDate.parse(day.date);
  final lunar = day.lunar;
  final solarTerm = day.solarTerm;
  final termName = solarTerm == null
      ? null
      : names?.valueName(_solarTermCategory, solarTerm.kind.value);

  final String lunarText;
  if (termName != null) {
    lunarText = termName;
  } else if (lunar.day == 1) {
    lunarText = '${lunar.month}.1';
  } else {
    lunarText = '${lunar.day}';
  }

  final parts = <String>[
    DateFormat.MMMMEEEEd(locale)
        .format(DateTime(date.year, date.month, date.day)),
    if (termName != null)
      termName
    else ...[
      l10n.dayCellLunar(lunar.month, lunar.day),
      if (lunar.isLeapMonth) l10n.dayCellLeapMonth,
    ],
    plainTextOf(day.level.text),
    if (diaryWritten) l10n.dayCellDiaryWritten,
    if (eventCount > 0) l10n.dayCellEventCount(eventCount),
    if (isToday) l10n.dayCellToday,
  ];

  return CalendarDayView(
    date: date,
    luck: day.luckLevel,
    lunarText: lunarText,
    lunarBold: termName != null,
    semanticLabel: parts.join(l10n.a11yListSeparator),
  );
}
