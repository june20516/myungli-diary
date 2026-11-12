import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/daily_cards.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/day_virtue.dart';
import 'package:myungli_diary/core/api/gen/model/day_virtue_kind.dart';
import 'package:myungli_diary/core/api/gen/model/direction.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/focus_time_card.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god_group.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/time_band.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/features/glossary/model/ganji_reading.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';

// 그날 응답(`Daily`)을 화면에 보일 값으로 바꾸는 한 곳입니다(결정 A22·A27).
// 계약 필드가 늘면 화면이 아니라 이 파일만 고칩니다. 오늘 화면과 계획 4 `day-sheet`,
// 공유 미리보기, 풀이·근거 시트(슬롯별 오늘 그런 이유·근거, [dailySlotText])가 함께 씁니다.
// 오늘 화면은 IA v5(D108)부터 날의 성격 이유(`characterReason`)를 그리지 않습니다. 이유는
// 공유 이미지 story 변형([shareImageContentOf])에만 남습니다.
// A22는 draft.4로 해제되어 계약의 문장 필드를 모두 그리고, 원고가 없어 server가 생략한
// 선택 문장만 자리 없이 건너뜁니다.

/// 날의 성격 줄(`day-character`)에 보일 값.
final class DayCharacterContent {
  /// 날의 성격 줄 값을 만듭니다.
  const new({required this.variant, required this.label, this.reason});

  /// 배지 변형.
  final DayCharacterVariant variant;

  /// 배지 글자(날의 성격 이름).
  final String label;

  /// 이유 한 줄(`character.reason`). 계약 draft.3부터 응답에 늘 있습니다.
  /// 원고가 없어 비어 있으면 [DayCharacter]가 이유 줄을 그리지 않습니다(A22 남은 규칙).
  final RenderedText? reason;
}

/// [daily]의 날의 성격 줄. 이름은 ARB(`dayKind*`)에서 고릅니다(A20 ①).
///
/// 이유 줄은 응답의 `characterReason`(슬롯 `character.reason`, 계약 draft.3)입니다.
DayCharacterContent dayCharacterOf(Daily daily, AppLocalizations l10n) =>
    DayCharacterContent(
      variant: dayCharacterVariantOf(daily.dayKind),
      label: dayKindName(l10n, daily.dayKind),
      reason: daily.characterReason.text,
    );

/// 행운 방향 이름(writing 원고 키 `direction8*`, glossary 범주 `direction8`, 결정 W23).
String directionName(AppLocalizations l10n, Direction direction) =>
    switch (direction) {
      Direction.n => l10n.direction8N,
      Direction.ne => l10n.direction8Ne,
      Direction.e => l10n.direction8E,
      Direction.se => l10n.direction8Se,
      Direction.s => l10n.direction8S,
      Direction.sw => l10n.direction8Sw,
      Direction.w => l10n.direction8W,
      Direction.nw => l10n.direction8Nw,
    };

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _hourMinute(DateTime instant, String timezone) {
  final local = localTimeIn(instant, timezone);
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

/// 언어별 시간 범위의 시작과 끝 사이 글자(`lucky-card` `time.parts.value.format`, 결정 V52,
/// writing W44). 앱 언어는 ko, en, ja이고 그 밖의 언어는 앱이 en으로 보이므로 en을 씁니다.
String _rangeJoinOf(String languageCode) => switch (languageCode) {
  'ko' => '~',
  'ja' => '〜',
  _ => ' to ',
};

/// [l10n]의 언어 코드(`ko_KR`이면 `ko`).
String _languageCodeOf(AppLocalizations l10n) =>
    l10n.localeName.split(RegExp('[_-]')).first;

/// 집중 시간 구간 하나를 [timezone](프로필 시간대) 현지 24시간 `HH:mm`으로 쓰고, 시작과 끝을
/// [languageCode]의 범위 표기로 잇습니다(ko `09:30~11:30`, ja `09:30〜11:30`,
/// en `09:30 to 11:30`).
///
/// 응답 시각은 오프셋이 붙어 오지만 같은 순간이면 UTC로 바뀌어도 같은 값입니다(결정 A27).
String formatFocusRange(FocusSlot pick, String timezone, String languageCode) =>
    '${_hourMinute(pick.start, timezone)}'
    '${_rangeJoinOf(languageCode)}'
    '${_hourMinute(pick.end, timezone)}';

/// 낮 카드 `hours`가 없는 응답의 낮 구간 시작 벽시계 시각 07:30. 계약 `openapi.yaml`
/// `DailyCards`(1.12.0): "`hours`가 없는 응답(규칙 버전 2026.11.8 전)은 한국 시각 07:30으로
/// 봅니다"(#1064). 밤 칩 전환은 그날 한국 시각 이 시각이고([dayStartOf]), 계약이 그 응답의 띠 칸을
/// 정하지 않아 띠는 A134 방식대로 프로필 시간대 벽시계 이 시각에서 시진 길이로 셉니다(A140 ①③).
const Duration _fallbackDayStartWall = Duration(hours: 7, minutes: 30);

/// 한국 시각의 UTC offset(+09:00, 서머타임 없음). [_fallbackDayStartWall]을 순간으로 바꿀 때만
/// 씁니다.
const Duration _koreaOffset = Duration(hours: 9);

/// 시진 하나의 길이(`timeBand` `cells.unit`).
const Duration _hourBranchLength = Duration(hours: 2);

/// 낮 구간의 시진(진시~술시, D122 ①). 띠의 낮 일곱 칸 순서입니다.
const List<Branch> _dayBranches = [
  Branch.jin,
  Branch.sa,
  Branch.o,
  Branch.mi,
  Branch.shin,
  Branch.yu,
  Branch.sul,
];

/// 밤 구간의 시진(해시~묘시, D122 ①). 띠의 밤 다섯 칸 순서입니다.
const List<Branch> _nightBranches = [
  Branch.hae,
  Branch.ja,
  Branch.chuk,
  Branch.in_,
  Branch.myo,
];

/// [daily]의 낮 구간이 시작하는 순간(그날 진시 시작, D122 ⑦, #1064). 계약 `DailyCards`의 전환
/// 시각 `focusTime.hours[0].start`이고, 받은 순서를 고치지 않고 가장 이른 시작을 읽습니다. 낮 카드
/// `hours`가 없거나 비면(규칙 버전 2026.11.8 전) 그날 한국 시각 07:30입니다(A140 ①).
DateTime dayStartOf(Daily daily) {
  final hours = daily.cards.focusTime.hours ?? const <FocusSlot>[];
  if (hours.isEmpty) {
    final date = CalendarDate.parse(daily.date);
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(_fallbackDayStartWall - _koreaOffset);
  }
  return hours
      .map((hour) => hour.start)
      .reduce((earliest, start) => start.isBefore(earliest) ? start : earliest);
}

/// [wallNow](프로필 시간대 [timezone]의 벽시계, `nowMinuteProvider` 값)가 그날 낮 구간 시작
/// [dayStart]([dayStartOf]) 전인지. 밤 칩 고르기와 때 낱말(D122 ⑦, V116), 24시간 띠 순서(V117)의
/// 판단은 이 함수 하나입니다. [dayStart]를 같은 시간대 벽시계로 바꿔 비교하므로 두 순간의 비교와
/// 같고, 기기 시간대는 쓰지 않습니다(A140 ②).
bool isBeforeDayStart(
  DateTime wallNow, {
  required DateTime dayStart,
  required String timezone,
}) => wallNow.isBefore(_wallClockOf(dayStart, timezone));

/// [instant]를 [timezone] 벽시계 숫자로 바꿔 UTC 그릇에 담습니다(`nowMinuteProvider` 값과 같은 모양).
DateTime _wallClockOf(DateTime instant, String timezone) {
  final local = localTimeIn(instant, timezone);
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
  );
}

/// 계약 `DailyCards`의 카드 필드(`openapi.yaml`). 이름이 계약 필드 이름과 같고, 카드 근거 id
/// ([dailyCardSlotId])가 이 이름을 씁니다.
enum DailyCardField {
  /// 첫째 색 카드.
  color,

  /// 색이 둘인 날의 둘째 색 카드(D119 ②).
  secondColor,

  /// 방향 카드.
  direction,

  /// 숫자 카드.
  number,

  /// 낮 집중 시간 카드.
  focusTime,

  /// 그날 밤 집중 시간 카드(D122 ⑦).
  nightFocusTime,

  /// 전날 밤 집중 시간 카드(오늘 요청에만, D122 ⑦).
  previousNightFocusTime;

  /// [cards]에서 이 카드의 문장. 그 카드가 응답에 없으면 null입니다.
  SlotText? textIn(DailyCards cards) => switch (this) {
    color => cards.color.text,
    secondColor => cards.secondColor?.text,
    direction => cards.direction.text,
    number => cards.number.text,
    focusTime => cards.focusTime.text,
    nightFocusTime => cards.nightFocusTime?.text,
    previousNightFocusTime => cards.previousNightFocusTime?.text,
  };
}

/// 같은 writing 슬롯을 여러 카드가 함께 쓰는 자리에서 근거 시트가 카드 하나를 찾는 카드 id
/// (`<슬롯>#<카드 필드 이름>`, A134). 집중 시간 낮과 밤 카드는 모두 `daily.focus_time`이라
/// 슬롯만으로는 첫 카드(낮)의 근거가 열립니다. [dailySlotText]가 이 id를 읽습니다.
String dailyCardSlotId(SlotText text, DailyCardField field) =>
    '${text.slot}#${field.name}';

/// 덕일 풀이 문장의 근거 id(`<슬롯>#<덕 종류 값>`, 예 `explain.day_virtue#cheondeok_day`).
/// 천덕일과 월덕일 문장은 같은 슬롯 `explain.day_virtue`라 카드 id(A134)처럼 덕 종류로 하나를
/// 찾습니다. [dailySlotText]가 이 id를 읽습니다.
String dailyVirtueSlotId(DayVirtue virtue) =>
    '${virtue.text.slot}#${virtue.kind.value}';

/// 오늘 화면 시간 칩 하나가 가리키는 카드와 그 근거 id([dailyCardSlotId]).
typedef FocusTimePick = ({FocusTimeCard card, String evidenceSlotId});

/// 오늘 화면의 [period] 시간 칩 카드. 낮은 `focusTime`, 밤은 낮 구간 시작 전이면
/// `previousNightFocusTime`(지금 이어지는 전날 밤), 그 뒤면 `nightFocusTime`(오늘 밤)입니다
/// (D122 ⑦, `DailyCards` 설명). 고른 밤 카드가 응답에 없으면 null이고 밤 칩을 그리지 않습니다.
/// 낮 구간 시작 전에 전날 밤이 없을 때 오늘 밤으로 대신하지 않습니다(때 낱말과 띠 순서가 어긋남, A134).
FocusTimePick? focusTimePickOf(
  DailyCards cards,
  AppTimeOfDay period, {
  required bool beforeDayStart,
}) {
  final (card, field) = switch (period) {
    AppTimeOfDay.day => (cards.focusTime, DailyCardField.focusTime),
    AppTimeOfDay.night when beforeDayStart => (
      cards.previousNightFocusTime,
      DailyCardField.previousNightFocusTime,
    ),
    AppTimeOfDay.night => (cards.nightFocusTime, DailyCardField.nightFocusTime),
  };
  if (card == null) return null;
  return (card: card, evidenceSlotId: dailyCardSlotId(card.text, field));
}

/// [daily]의 행운 항목(색, 방향, 숫자, 그리고 시간 낮 칩과 밤 칩, 결정 A27, V115, V116).
///
/// 색 이름은 glossary `color.<오행>`(없으면 값 id 그대로)이고, 색이 둘인 날(`secondColor`, D119 ②)은
/// 색 항목 하나에 둘째 색을 담아 칩이 두 칸 알약이 됩니다(V114). 숫자는 server가 첫째 색 기준으로
/// 계산해 주는 값 그대로입니다(D119 ③). 방향은 임시 ARB, 숫자는 그대로,
/// 시간은 카드마다 첫 구간 하나의 [formatFocusRange]입니다(D122 ⑤ 칩마다 시간 하나). 시간 칩
/// 이름은 그 칩의 시트 제목이고(`a11y.timeLabel`), 밤 칩은 [beforeDayStart]로 카드와 때 낱말을
/// 고릅니다([focusTimePickOf]). 색 칩의 견본 색은 칩이 테마에서 고릅니다.
List<LuckyItem> luckyItemsOf(
  Daily daily,
  GlossaryNames names,
  AppLocalizations l10n,
  String timezone, {
  required bool beforeDayStart,
}) {
  final cards = daily.cards;
  final element = cards.color.element;
  final second = cards.secondColor;
  final language = _languageCodeOf(l10n);
  final night = focusTimePickOf(
    cards,
    AppTimeOfDay.night,
    beforeDayStart: beforeDayStart,
  );
  return [
    LuckyItem(
      variant: LuckyCardVariant.color,
      name: l10n.todayLuckyColorName,
      value: _colorName(names, element),
      explain: cards.color.text.text,
      element: element,
      secondColor: second == null
          ? null
          : LuckySecondColor(
              element: second.element,
              value: _colorName(names, second.element),
              explain: second.text.text,
            ),
    ),
    LuckyItem(
      variant: LuckyCardVariant.direction,
      name: l10n.todayLuckyDirectionName,
      value: directionName(l10n, cards.direction.direction),
      explain: cards.direction.text.text,
    ),
    LuckyItem(
      variant: LuckyCardVariant.number,
      name: l10n.todayLuckyNumberName,
      value: '${cards.number.number}',
      explain: cards.number.text.text,
    ),
    LuckyItem(
      variant: LuckyCardVariant.time,
      name: l10n.todayLuckyTimeDayTitle,
      value: formatFocusRange(cards.focusTime.picks.first, timezone, language),
      explain: cards.focusTime.text.text,
      period: AppTimeOfDay.day,
    ),
    if (night != null)
      LuckyItem(
        variant: LuckyCardVariant.time,
        name: l10n.todayLuckyTimeNightTitle,
        word: beforeDayStart
            ? l10n.todayLuckyTimeNightDawn
            : l10n.todayLuckyTimeNightTonight,
        value: formatFocusRange(night.card.picks.first, timezone, language),
        explain: night.card.text.text,
        period: AppTimeOfDay.night,
      ),
  ];
}

/// [element] 색 이름(glossary `color.<오행>`, 없으면 값 id 그대로).
String _colorName(GlossaryNames names, FiveElement element) =>
    names.valueName('color', element.value) ?? element.value;

/// [branch]를 띠 칸에 쓸 글자. ko, ja는 사전 지지 이름(writing `glossary.value_name`
/// `branch.*`, ko "자", ja "子")이고 사전에 없으면 지지 한자입니다. 원고 슬롯
/// `today.lucky-time.band.tomorrow`가 "띠 칸 시진 이름은 glossary 지지 이름"이라고 정합니다.
/// en과 그 밖의 언어는 지지 한자입니다(동물 이름은 칸에 들어가지 않음, `timeBand`
/// `cells.label`, V118 ⑤).
String _bandLabelOf(Branch branch, GlossaryNames names, bool hanjaLabels) =>
    hanjaLabels
    ? branchHanja(branch)
    : names.valueName('branch', branch.value) ?? branchHanja(branch);

/// 띠 칸 하나가 될 시진: 지지와 프로필 시간대 벽시계의 시작, 끝(UTC 그릇, [_wallClockOf]).
typedef _BandHour = ({Branch branch, DateTime start, DateTime end});

/// 받은 구간 시진 [hours]를 띠 칸 값으로 바꿉니다. 같은 시진이 두 번 오면 시작 순간으로 한 번만 두고
/// 시작 순서로 놓습니다(받은 값은 고치지 않음). 남은 수가 구간 칸 수 [count]가 아니면(없음, 빈 배열
/// 포함) null이라 그 구간은 지금 방식으로 그립니다(A140 ③).
List<_BandHour>? _bandHoursOf(
  List<FocusSlot>? hours,
  int count,
  String timezone,
) {
  final byStart = <DateTime, FocusSlot>{};
  for (final hour in hours ?? const <FocusSlot>[]) {
    byStart.putIfAbsent(hour.start, () => hour);
  }
  if (byStart.length != count) return null;
  final ordered = byStart.values.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (final hour in ordered)
      (
        branch: hour.branch,
        start: _wallClockOf(hour.start, timezone),
        end: _wallClockOf(hour.end, timezone),
      ),
  ];
}

/// [branches]를 [start](벽시계)부터 시진 길이로 이어 붙인 띠 칸 값(지금 방식, A134 ⑦).
List<_BandHour> _tableHoursFrom(DateTime start, List<Branch> branches) => [
  for (final (index, branch) in branches.indexed)
    (
      branch: branch,
      start: start.add(_hourBranchLength * index),
      end: start.add(_hourBranchLength * (index + 1)),
    ),
];

/// 시간 칩 시트의 24시간 띠(`timeBand`, V117). 지금 보이는 낮, 밤 칩의 24시간을 시진 12칸으로
/// 그리고, 낮 구간 시작 전에는 밤 다섯 칸이 앞, 그 뒤에는 낮 일곱 칸이 앞입니다. 고리는 두 칩이 고른
/// 시진(카드 첫 구간의 `branch`)이고, 시트를 연 칩([opened])의 시진은 [TimeBandPick.opened], 다른
/// 칩의 시진은 [TimeBandPick.other]입니다(V124). 밤 칩이 없으면 밤 칸에 고리가 없습니다.
/// [beforeDayStart]는 시트를 연 때의 값이라, 시트가 열린 채 낮 구간 시작을 지나도 칸 순서와 고리는
/// 연 칩 그대로이고 지금 줄만 움직입니다(A134 ⑧). [wallNow]는 프로필 시간대 [timezone]의
/// 벽시계(`nowMinuteProvider` 값)이고 지금 줄과 꼬리표가 됩니다.
///
/// 칸과 눈금은 그날 낮 카드와 보이는 밤 카드의 `hours`입니다(계약 `FocusTimeCard`, #1064). 낮 카드
/// `hours`가 없으면 띠 전체를 지금 방식(그날 프로필 벽시계 07:30부터 시진 길이)으로 그리고, 보이는 밤
/// 카드가 없거나 그 `hours`가 없으면 밤 다섯 칸만 낮 칸에 이어 시진 길이로 셉니다(A140 ③).
TimeBand timeBandOf({
  required Daily daily,
  required GlossaryNames names,
  required AppLocalizations l10n,
  required bool beforeDayStart,
  required AppTimeOfDay opened,
  required String timezone,
  required DateTime wallNow,
}) {
  final before = beforeDayStart;
  final cards = daily.cards;
  final dayPick = cards.focusTime.picks.first.branch;
  final nightCard = focusTimePickOf(
    cards,
    AppTimeOfDay.night,
    beforeDayStart: before,
  )?.card;
  final nightPick = nightCard?.picks.first.branch;
  final language = _languageCodeOf(l10n);
  final hanjaLabels = language != 'ko' && language != 'ja';

  final dayFromHours = _bandHoursOf(
    cards.focusTime.hours,
    _dayBranches.length,
    timezone,
  );
  final date = CalendarDate.parse(daily.date);
  final dayHours =
      dayFromHours ??
      _tableHoursFrom(
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).add(_fallbackDayStartWall),
        _dayBranches,
      );
  // 낮 칸이 지금 방식이면 밤 칸도 지금 방식이라 칸이 이어집니다.
  final nightFromHours = dayFromHours == null
      ? null
      : _bandHoursOf(nightCard?.hours, _nightBranches.length, timezone);
  final nightLength = _hourBranchLength * _nightBranches.length;
  final nightHours =
      nightFromHours ??
      _tableHoursFrom(
        before ? dayHours.first.start.subtract(nightLength) : dayHours.last.end,
        _nightBranches,
      );

  List<TimeBandCell> cellsOf(
    List<_BandHour> hours,
    AppTimeOfDay period,
    Branch? pick,
  ) => [
    for (final hour in hours)
      TimeBandCell(
        label: _bandLabelOf(hour.branch, names, hanjaLabels),
        period: period,
        pick: TimeBandPick.of(
          period,
          opened: opened,
          chosen: hour.branch == pick,
        ),
      ),
  ];

  final dayCells = cellsOf(dayHours, AppTimeOfDay.day, dayPick);
  final nightCells = cellsOf(nightHours, AppTimeOfDay.night, nightPick);
  final (first, second) = before
      ? (nightHours, dayHours)
      : (dayHours, nightHours);
  final bandStart = first.first.start;
  final bandEnd = second.last.end;
  final elapsed = wallNow.difference(bandStart).inSeconds;
  final span = bandEnd.difference(bandStart).inSeconds;
  return TimeBand(
    cells: before ? [...nightCells, ...dayCells] : [...dayCells, ...nightCells],
    dayHead: l10n.todayLuckyTimeBandDay,
    nightHead: l10n.todayLuckyTimeBandNight,
    nowFraction: (elapsed / span).clamp(0.0, 1.0),
    nowLabel: l10n.todayLuckyTimeBandNow(_wallText(wallNow)),
    startTick: TimeBandTick(
      time: _wallText(bandStart),
      dayWord: before ? l10n.todayLuckyTimeBandYesterday : null,
    ),
    boundaryTick: TimeBandTick(time: _wallText(second.first.start)),
    endTick: TimeBandTick(
      time: _wallText(bandEnd),
      dayWord: before ? null : l10n.todayLuckyTimeBandTomorrow,
    ),
    hanjaLabels: hanjaLabels,
  );
}

/// 벽시계 [wall](UTC 그릇)의 `HH:mm`.
String _wallText(DateTime wall) =>
    '${_twoDigits(wall.hour)}:${_twoDigits(wall.minute)}';

/// 대표 태그 [tag]를 `hanja-tag`로 그릴 값. 사전에 이름이 없거나 한자 글자표(A112)에 없으면
/// null입니다. [rank]는 응답 `tags.featured` 안 순번입니다. 오늘 화면과 사주 기운 시트가 함께 씁니다.
FeaturedTagContent? featuredTagContentOf(
  Tag tag,
  int rank,
  GlossaryNames names,
) {
  final label = names.valueName('tag', tag.key);
  final glyph = HanjaGlyphs.forTagKey(tag.key);
  if (label == null || glyph == null) return null;
  return FeaturedTagContent(
    rank: rank,
    key: tag.key,
    glyph: glyph,
    label: label,
  );
}

/// [daily]의 대표 태그 중 그릴 수 없는 키(응답 순서). 사전에 이름이 없거나 한자 글자표(A112)에
/// 없는 태그입니다.
///
/// 사전과 계약이 어긋난 것을 알 수 있게 오늘 화면 값이 이 키를 보고합니다
/// (`todayContentProvider`). 대표 태그 표시는 사주 기운 섹션의 `hanja-tag`입니다(V78).
List<String> skippedFeaturedTagKeysOf(Daily daily, GlossaryNames names) => [
  for (final (rank, tag) in daily.tags.featured.indexed)
    if (featuredTagContentOf(tag, rank, names) == null) tag.key,
];

/// [daily]에서 writing 슬롯 id가 [slotId]인 문장. 응답에 없는 슬롯이면 null입니다.
///
/// 날의 성격 이유·총운(첫 문장·태그 문장)·가이드 질문·행운 카드 문장을 찾습니다. 풀이 시트는
/// 이 문장의 `todayReason`(오늘 그런 이유)을, 근거 시트는 `evidence`를 씁니다. 카드 id
/// ([dailyCardSlotId], `<슬롯>#<카드>`)면 그 카드의 문장이고, 덕일 id([dailyVirtueSlotId],
/// `<슬롯>#<덕 종류>`)면 그 덕의 풀이 문장입니다. 그 카드나 덕이 없거나 슬롯이 다르면 null입니다.
SlotText? dailySlotText(Daily daily, String slotId) {
  final cards = daily.cards;
  final mark = slotId.indexOf('#');
  if (mark >= 0) {
    final slot = slotId.substring(0, mark);
    final suffix = slotId.substring(mark + 1);
    final field = DailyCardField.values.asNameMap()[suffix];
    final text = field == null
        ? daily.dayVirtues
              .where((virtue) => virtue.kind.isKnown)
              .where((virtue) => virtue.kind.value == suffix)
              .firstOrNull
              ?.text
        : field.textIn(cards);
    return text?.slot == slot ? text : null;
  }
  final slots = [
    daily.characterReason,
    daily.fortune.head,
    ?daily.fortune.tag,
    daily.guide,
    cards.color.text,
    cards.direction.text,
    cards.number.text,
    cards.focusTime.text,
  ];
  for (final slot in slots) {
    if (slot.slot == slotId) {
      return slot;
    }
  }
  return null;
}

/// `time_unknown` notice가 있는지. 오늘 화면의 안내 문구는 사주 표와 같은 ARB
/// (`sajuChartTimeUnknownNotice`, IA today `time-unknown`)라 server 문장은 쓰지 않습니다.
bool hasTimeUnknownNotice(Daily daily) =>
    daily.notices.any((notice) => notice.code == NoticeCode.timeUnknown);

/// 오늘 화면 한 줄 문장(총운 첫 문장·태그 문장)과 그 문장이 채우는 writing 슬롯.
@immutable
final class SentenceLine {
  /// [text]와 그 슬롯 [slot]입니다.
  const new({required this.text, required this.slot});

  /// server가 렌더한 문장.
  final RenderedText text;

  /// writing 슬롯 id(용어·근거 시트가 받음).
  final String slot;

  /// 원고가 없어 글자가 없거나 공백뿐인 문장이면 true. 그리면 빈 카드가 되므로 화면이 건너뜁니다.
  bool get isBlank => isBlankText(text);
}

/// 오늘 화면 대표 태그 하나(`hanja-tag`, 사주 기운 섹션과 보조 문장 위 태그).
@immutable
final class FeaturedTagContent {
  /// 대표 태그 값을 만듭니다.
  const new({
    required this.rank,
    required this.key,
    required this.glyph,
    required this.label,
  });

  /// 응답 `tags.featured` 안 순번(0이 1순위). 사주 기운 시트가 이 순번으로 엽니다(A113).
  final int rank;

  /// 태그 키(glossary `tag` 범주 값).
  final String key;

  /// 원 안 한자 한 글자(A112).
  final String glyph;

  /// 태그 이름(사전).
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FeaturedTagContent &&
      other.rank == rank &&
      other.key == key &&
      other.glyph == glyph &&
      other.label == label;

  @override
  int get hashCode => Object.hash(rank, key, glyph, label);
}

/// 오늘 화면에 보이는 대표 태그 상한(사주 기운 섹션 "최대 둘", IA `today.featured.title`).
const int maxFeaturedTags = 2;

/// 오늘 화면이 그리는 값 묶음. 화면은 이 값으로만 내용을 그립니다.
///
/// 값 동등성(`==`)이 있어 캐시 → server 응답으로 바뀔 때 보이는 내용이 같은지 이 값으로
/// 비교합니다(`SeepOnChange.changeKey`). 보이지 않는 필드(`evidenceAccess`, `evidence`,
/// `reaction`, 규칙 버전, 날의 성격 이유 등)는 담지 않으므로 그것만 바뀌면 같은 값입니다. 계약
/// 필드가 늘어 화면에 그리면 이 클래스에 필드를 더하고 [_props]에 넣습니다. 비교 방식은
/// [_canonical] 한 곳이 정하고, 모르는 타입이 들어오면 던지므로 빠뜨린 정규화는 테스트에서
/// 드러납니다.
@immutable
final class TodayDisplay {
  /// 오늘 화면 값을 만듭니다.
  const new({
    required this.lunarText,
    required this.iljin,
    required this.virtues,
    required this.dayKind,
    required this.dayKindLabel,
    required this.tenGodGroup,
    required this.tenGodGroupLabel,
    required this.timeUnknown,
    required this.head,
    required this.headReactable,
    required this.body,
    required this.featured,
    required this.featuredEmpty,
    required this.lucky,
    required this.guide,
  });

  /// 날짜 머리의 음력 글자(`today.date.lunar`). 응답에 음력이 없으면 null입니다.
  final String? lunarText;

  /// 날짜 머리의 일진 글자(`today.date.iljin`, 화면 `庚申(경신)일`, 스크린리더 `경신일`).
  final IljinText iljin;

  /// 날짜 머리의 덕일 알약(`today.date.virtue`, 천덕일, 월덕일 순서, [dayVirtuesOf]). 덕일이 아닌 날은
  /// 비어 있습니다.
  final List<DayVirtueContent> virtues;

  /// 날의 성격(총운 결정 태그 첫째, `today.character.label`).
  final DayKind dayKind;

  /// 날의 성격 이름(ARB).
  final String dayKindLabel;

  /// 일진 천간의 십성 묶음(총운 결정 태그 둘째, `today.ten-god.label`). 응답에 없으면 null입니다.
  final TenGodGroup? tenGodGroup;

  /// 십성 묶음 이름(사전). 묶음이 없거나 사전에 이름이 없으면 null이고, 화면은 그 태그를
  /// 그리지 않습니다.
  final String? tenGodGroupLabel;

  /// 시간 모름 안내를 보일지(`time_unknown` notice).
  final bool timeUnknown;

  /// 총운 헤드라인.
  final SentenceLine head;

  /// 총운 헤드라인에 반응 버튼을 두는지(`reactable`).
  final bool headReactable;

  /// 총운 보조 문장(`fortune.tag`). 대표 태그가 없는 날(D112)이나 응답에 없으면 null입니다.
  final SentenceLine? body;

  /// 그릴 수 있는 대표 태그(앞 [maxFeaturedTags]개 중, 응답 순서).
  final List<FeaturedTagContent> featured;

  /// server `tags.featured`가 실제로 빈 날(D112)인지. 태그가 왔지만 사전이나 글자표에 없어
  /// [featured]만 빈 날은 false이고, 그날은 D112 안내 없이 사주 기운 섹션째 두지 않습니다.
  final bool featuredEmpty;

  /// 행운 항목(색, 방향, 숫자, 시간 낮과 밤). 밤 카드가 없으면 시간은 낮 하나입니다.
  final List<LuckyItem> lucky;

  /// 가이드 질문.
  final RenderedText guide;

  /// 보조 문장 위 태그(대표 태그 1순위). 보조 문장이 없거나 1순위를 그릴 수 없으면 null입니다.
  /// 1순위를 그릴 수 없는 날은 D112가 아니므로 보조 문장과 선은 그대로 두고 태그 자리만 비웁니다.
  FeaturedTagContent? get bodyTag =>
      body == null ? null : featured.where((tag) => tag.rank == 0).firstOrNull;

  /// 동등성에 쓰는 필드 목록. 화면에 그리는 필드는 모두 여기에 있습니다.
  List<Object?> get _props => [
    lunarText,
    iljin.shown,
    iljin.spoken,
    virtues,
    dayKind,
    dayKindLabel,
    tenGodGroup,
    tenGodGroupLabel,
    timeUnknown,
    head,
    headReactable,
    body,
    featured,
    featuredEmpty,
    lucky,
    guide,
  ];

  /// 정규화한 [_props]의 JSON 글자. 생성 모델의 `==`는 목록을 참조로 비교하므로 글자로 비교합니다.
  String get _signature => jsonEncode(_canonical(_props));

  @override
  bool operator ==(Object other) =>
      other is TodayDisplay && other._signature == _signature;

  @override
  int get hashCode => _signature.hashCode;
}

/// [value]를 JSON으로 쓸 수 있는 비교용 값으로 바꿉니다. 모르는 타입이면 [ArgumentError]입니다.
Object? _canonical(Object? value) => switch (value) {
  null || String() || num() || bool() => value,
  Enum() => value.name,
  RenderedText() => value.toJson(),
  SentenceLine() => [value.slot, value.text.toJson()],
  FeaturedTagContent() => [value.rank, value.key, value.glyph, value.label],
  DayVirtueContent() => [
    value.kind.value,
    value.glyph,
    value.label,
    value.body.toJson(),
    value.evidenceSlotId,
  ],
  LuckyItem() => [
    value.variant.name,
    value.name,
    value.value,
    value.explain.toJson(),
    value.element?.name,
    value.period?.name,
    value.word,
    value.secondColor?.element.name,
    value.secondColor?.value,
    value.secondColor?.explain.toJson(),
  ],
  Iterable<Object?>() => [for (final item in value) _canonical(item)],
  _ => throw ArgumentError.value(value, 'value', '비교 방식을 정하지 않은 타입입니다'),
};

/// [daily]의 음력 글자(`todayDateLunar`, 윤달이면 `todayDateLunarLeap`). 없으면 null입니다.
String? lunarTextOf(Daily daily, AppLocalizations l10n) {
  final lunar = daily.lunar;
  if (lunar == null) return null;
  return lunar.isLeapMonth
      ? l10n.todayDateLunarLeap(lunar.month, lunar.day)
      : l10n.todayDateLunar(lunar.month, lunar.day);
}

/// 날짜 머리 덕일 알약 하나(`date-header` `parts.virtue`, D124 ⑤, V119)와 그 풀이 시트 값.
@immutable
final class DayVirtueContent {
  /// 덕일 값을 만듭니다.
  const new({
    required this.kind,
    required this.glyph,
    required this.label,
    required this.body,
    required this.evidenceSlotId,
  });

  /// 덕 종류(같은 날 같은 덕을 한 번만 그리는 식별 키이자, 열린 시트를 가리키는 값).
  final DayVirtueKind kind;

  /// 원 안 한자(`glyphs.virtueDay`).
  final String glyph;

  /// 알약 이름이자 풀이 시트 제목(ARB `todayDateVirtue*`).
  final String label;

  /// 풀이 시트 본문(`DayVirtue.text`, 슬롯 `explain.day_virtue`).
  final RenderedText body;

  /// 근거 시트가 이 덕의 문장을 찾는 id([dailyVirtueSlotId]).
  final String evidenceSlotId;
}

/// 덕 이름(ARB `todayDateVirtueCheondeok`, `todayDateVirtueWoldeok`).
/// 모르는 값은 null입니다.
String? dayVirtueName(AppLocalizations l10n, DayVirtueKind kind) =>
    switch (kind) {
      DayVirtueKind.cheondeokDay => l10n.todayDateVirtueCheondeok,
      DayVirtueKind.woldeokDay => l10n.todayDateVirtueWoldeok,
      DayVirtueKind.unknownDefaultOpenApi => null,
    };

/// 덕일 알약 순서(design `date-header` `parts.virtue.perVirtue`, `a11y.virtueLabel`:
/// 천덕일, 월덕일). `openapi.yaml` `dayVirtues`는 순서를 정하지 않으므로 그리는 단계에서
/// 이 순서로 둡니다.
const List<DayVirtueKind> _dayVirtueOrder = [
  DayVirtueKind.cheondeokDay,
  DayVirtueKind.woldeokDay,
];

/// [daily]의 덕일 알약(계약 순서 [_dayVirtueOrder]). 열린 enum의 모르는 덕은 이름과 글자가 없어
/// 건너뛰고, 같은 덕이 두 번 오면 처음 하나만 둡니다(받은 데이터는 그대로, 그리는 단계에서
/// `kind`로 거르고 정렬). 덕일이 아닌 날(빈 배열)은 빈 목록이고 날짜 머리에 칸이 없습니다.
List<DayVirtueContent> dayVirtuesOf(Daily daily, AppLocalizations l10n) {
  final virtues = <DayVirtueKind, DayVirtueContent>{};
  for (final virtue in daily.dayVirtues) {
    if (virtues.containsKey(virtue.kind)) continue;
    final content = _dayVirtueContentOf(virtue, l10n);
    if (content != null) virtues[virtue.kind] = content;
  }
  return [for (final kind in _dayVirtueOrder) ?virtues[kind]];
}

DayVirtueContent? _dayVirtueContentOf(DayVirtue virtue, AppLocalizations l10n) {
  final label = dayVirtueName(l10n, virtue.kind);
  final glyph = HanjaGlyphs.forDayVirtue(virtue.kind);
  if (label == null || glyph == null) return null;
  return DayVirtueContent(
    kind: virtue.kind,
    glyph: glyph,
    label: label,
    body: virtue.text.text,
    evidenceSlotId: dailyVirtueSlotId(virtue),
  );
}

/// [daily]의 일진 글자(`todayDateIljin`). 간지 글자는 [ganjiTextOf]입니다.
IljinText iljinTextOf(Daily daily, AppLocalizations l10n) {
  final pillar = ganjiTextOf(daily.dayPillar, l10n);
  return IljinText(
    shown: l10n.todayDateIljin(pillar.shown),
    spoken: l10n.todayDateIljin(pillar.spoken),
  );
}

/// [pillar]의 간지 글자(W72, A133). 화면 글자 `shown`은 한자 뒤 괄호 독음(`庚申(경신)`,
/// en `庚申 (Gyeong Sin)`, ja `庚申（かのえさる）`, 틀 `ganjiReadingSuffix`)이고, 스크린리더 글자
/// `spoken`은 독음만(`경신`, 틀 `ganjiReading`)입니다. 한자는 틀에 넣지 않고 앞에 붙여,
/// 그리는 컴포넌트가 한자 덩어리를 한자 글꼴로 바꿉니다(오늘 날짜 머리, 일기 쓰기 날짜 블록).
GanjiText ganjiTextOf(Pillar pillar, AppLocalizations l10n) {
  final hanja = '${stemHanja(pillar.stem)}${branchHanja(pillar.branch)}';
  final reading = GanjiReading.pillar(pillar.stem, pillar.branch, l10n);
  return (shown: '$hanja${l10n.ganjiReadingSuffix(reading)}', spoken: reading);
}

/// 간지 글자: 화면 글자(한자 + 괄호 독음)와 스크린리더 글자(독음).
typedef GanjiText = ({String shown, String spoken});

/// [daily]를 오늘 화면 값으로 바꿉니다. 이름은 [names]·[l10n], 시각은 [timezone](프로필 시간대)이고,
/// [beforeDayStart]([isBeforeDayStart])가 밤 칩을 고릅니다.
TodayDisplay todayDisplayOf(
  Daily daily,
  GlossaryNames names,
  AppLocalizations l10n,
  String timezone, {
  required bool beforeDayStart,
}) {
  final featuredTags = daily.tags.featured;
  final tag = daily.fortune.tag;
  final group = daily.dayStemTenGodGroup;
  // 보조 문장은 대표 태그 1순위에서 나오므로 대표 태그가 없는 날은 그리지 않습니다(D112).
  final body = tag == null || featuredTags.isEmpty
      ? null
      : SentenceLine(text: tag.text, slot: tag.slot);
  return TodayDisplay(
    lunarText: lunarTextOf(daily, l10n),
    iljin: iljinTextOf(daily, l10n),
    virtues: dayVirtuesOf(daily, l10n),
    dayKind: daily.dayKind,
    dayKindLabel: dayKindName(l10n, daily.dayKind),
    tenGodGroup: group,
    tenGodGroupLabel: group == null
        ? null
        : names.valueName('ten_god_group', group.value),
    timeUnknown: hasTimeUnknownNotice(daily),
    head: SentenceLine(
      text: daily.fortune.head.text,
      slot: daily.fortune.head.slot,
    ),
    headReactable: daily.fortune.head.reactable,
    body: body,
    featured: [
      for (final (rank, featured) in featuredTags.take(maxFeaturedTags).indexed)
        ?featuredTagContentOf(featured, rank, names),
    ],
    featuredEmpty: featuredTags.isEmpty,
    lucky: luckyItemsOf(
      daily,
      names,
      l10n,
      timezone,
      beforeDayStart: beforeDayStart,
    ),
    guide: daily.guide.text,
  );
}

/// 공유 텍스트(OS 공유 시트의 글)가 연결된 writing 슬롯 id. 이미지 안에는 그리지 않습니다
/// (명세 `share-image` parts에 태그라인이 없음).
const String shareTextSlotId = SlotIds.sharePreviewImageTagline;

/// 공유할 때 이미지와 함께 보내는 글(`share-preview.image.tagline`).
String shareTextOf(AppLocalizations l10n) => l10n.sharePreviewImageTagline;

/// 공유 이미지에 쓰는 날짜 글자. 언어별 서식입니다(ko `10월 13일 화요일`).
String shareDateText(CalendarDate date, Locale locale) =>
    DateFormat.MMMMEEEEd(locale.toString())
        .format(DateTime(date.year, date.month, date.day));

/// 공유 이미지(`share-image`)에 들어갈 값. 비율과 무관하고, 위젯은 화면 쪽이 만듭니다.
@immutable
final class ShareImageContent {
  /// 공유 이미지 값을 만듭니다.
  const new({
    required this.date,
    required this.dayKind,
    required this.dayKindLabel,
    required this.sentence,
    required this.items,
    required this.footer,
    required this.reason,
  });

  /// 날짜 글자([shareDateText]).
  final String date;

  /// 날의 성격.
  final DayKind dayKind;

  /// 날의 성격 이름.
  final String dayKindLabel;

  /// 총운 첫 문장(호칭 포함).
  final RenderedText sentence;

  /// 행운 항목. 색은 첫째 색 칸 하나(D119 ④), 시간은 낮 칩 하나입니다(V116).
  final List<LuckyItem> items;

  /// 아래 글(`share-preview.image.footer`).
  final String footer;

  /// 날의 성격 이유. story 변형에서만 보입니다.
  final RenderedText? reason;
}

/// [daily]를 공유 이미지 값으로 바꿉니다.
///
/// 문장은 총운 첫 문장(`fortune.head`, 호칭 포함)이고, 이유는 오늘 화면과 같은 날의 성격
/// 이유(`characterReason`)입니다.
ShareImageContent shareImageContentOf({
  required CalendarDate date,
  required Daily daily,
  required GlossaryNames names,
  required AppLocalizations l10n,
  required Locale locale,
  required String timezone,
}) {
  final character = dayCharacterOf(daily, l10n);
  return ShareImageContent(
    date: shareDateText(date, locale),
    dayKind: daily.dayKind,
    dayKindLabel: character.label,
    sentence: daily.fortune.head.text,
    // 공유 이미지는 낮 칩 하나라(V116) 오늘 화면 칩 줄에서 밤 칩을 거릅니다. 밤 칩은 버리므로
    // 어느 밤 카드를 고르는지(beforeDayStart)는 결과에 영향이 없습니다. 색이 둘인 날도 첫째 색
    // 칸 하나입니다(D119 ④).
    items: [
      for (final item in luckyItemsOf(
        daily,
        names,
        l10n,
        timezone,
        beforeDayStart: false,
      ))
        if (item.period != AppTimeOfDay.night) item.withoutSecondColor,
    ],
    footer: l10n.sharePreviewImageFooter,
    reason: character.reason,
  );
}
