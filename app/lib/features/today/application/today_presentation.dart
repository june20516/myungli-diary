import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/daily_cards.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/direction.dart';
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

/// 오늘 화면의 낮 구간 시작(그날 진시 시작)의 프로필 시간대 벽시계 시각(`lucky-card` `time`
/// night `word.switch`, D122 ⑦). 지휘 답 #1063: 기준은 "프로필 현재 시간대에서 그날 진시가 시작하는
/// 시각"이고, server #1064가 그 경계 값을 줄 때까지 07:30으로 둡니다(한국 프로필은 결과가 같음, A134).
const Duration _dayStart = Duration(hours: 7, minutes: 30);

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

/// 하루의 분.
const int _minutesPerDay = 24 * 60;

/// [wallNow](프로필 시간대 벽시계, `nowMinuteProvider` 값처럼 시와 분만 읽음)가 그날 낮 구간 시작
/// 전인지. 밤 칩 고르기와 때 낱말(D122 ⑦, V116), 24시간 띠 순서(V117)의 판단은 이 함수 하나입니다.
/// #1064 경계 값이 오면 [_dayStart] 대신 그 값을 보도록 이 함수만 바꿉니다(A134).
bool isBeforeDayStart(DateTime wallNow) =>
    Duration(hours: wallNow.hour, minutes: wallNow.minute) < _dayStart;

/// 같은 writing 슬롯을 여러 카드가 함께 쓰는 자리에서 근거 시트가 카드 하나를 찾는 id
/// (`<슬롯>#<카드 필드 이름>`, A134). 집중 시간 낮과 밤 카드는 모두 `daily.focus_time`이라
/// 슬롯만으로는 첫 카드(낮)의 근거가 열립니다. [dailySlotText]가 이 id를 읽습니다.
String dailyCardSlotId(SlotText text, String cardField) =>
    '${text.slot}#$cardField';

/// 계약 `DailyCards`의 필드 이름(`openapi.yaml`)으로 고른 카드 문장. 그 카드가 응답에 없으면 null입니다.
SlotText? _cardText(DailyCards cards, String field) => switch (field) {
  'color' => cards.color.text,
  'secondColor' => cards.secondColor?.text,
  'direction' => cards.direction.text,
  'number' => cards.number.text,
  'focusTime' => cards.focusTime.text,
  'nightFocusTime' => cards.nightFocusTime?.text,
  'previousNightFocusTime' => cards.previousNightFocusTime?.text,
  _ => null,
};

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
    AppTimeOfDay.day => (cards.focusTime, 'focusTime'),
    AppTimeOfDay.night when beforeDayStart => (
      cards.previousNightFocusTime,
      'previousNightFocusTime',
    ),
    AppTimeOfDay.night => (cards.nightFocusTime, 'nightFocusTime'),
  };
  if (card == null) return null;
  return (card: card, evidenceSlotId: dailyCardSlotId(card.text, field));
}

/// [daily]의 행운 항목(색, 방향, 숫자, 그리고 시간 낮 칩과 밤 칩, 결정 A27, V115, V116).
///
/// 색 이름은 glossary `color.<오행>`(없으면 값 id 그대로), 방향은 임시 ARB, 숫자는 그대로,
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
      value: names.valueName('color', element.value) ?? element.value,
      explain: cards.color.text.text,
      element: element,
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

/// 벽시계 [minutes](0시부터, 하루를 넘으면 되감음)의 `HH:mm`.
String _clockText(int minutes) {
  final wrapped = minutes % _minutesPerDay;
  return '${_twoDigits(wrapped ~/ 60)}:${_twoDigits(wrapped % 60)}';
}

/// [branch]를 띠 칸에 쓸 글자. ko, ja는 사전 지지 이름(writing `glossary.value_name`
/// `branch.*`, ko "자", ja "子")이고 사전에 없으면 지지 한자입니다. 원고 슬롯
/// `today.lucky-time.band.tomorrow`가 "띠 칸 시진 이름은 glossary 지지 이름"이라고 정합니다.
/// en과 그 밖의 언어는 지지 한자입니다(동물 이름은 칸에 들어가지 않음, `timeBand`
/// `cells.label`, V118 ⑤).
String _bandLabelOf(Branch branch, GlossaryNames names, bool hanjaLabels) =>
    hanjaLabels
    ? branchHanja(branch)
    : names.valueName('branch', branch.value) ?? branchHanja(branch);

/// 시간 칩 시트의 24시간 띠(`timeBand`, V117). 지금 보이는 낮, 밤 칩의 24시간을 시진 12칸으로
/// 그리고, 낮 구간 시작 전에는 밤(전날 21:30부터) 다섯 칸이 앞, 그 뒤에는 낮(07:30부터) 일곱 칸이
/// 앞입니다. 고리는 두 칩이 고른 시진(카드 첫 구간의 `branch`)이고, 밤 칩이 없으면 밤 칸에 고리가
/// 없습니다. [wallNow]는 프로필 시간대 벽시계(시와 분만 읽음)이고 지금 줄과 꼬리표가 됩니다.
///
/// 칸 경계와 눈금은 [_dayStart]에서 시진 길이로 셉니다. 시간대가 한국이 아닌 프로필은 칩 값(프로필
/// 시간대로 바꾼 시진 시각)과 칸 경계가 어긋날 수 있고 #1064 경계 값으로 함께 맞춥니다(A134).
TimeBand timeBandOf({
  required Daily daily,
  required GlossaryNames names,
  required AppLocalizations l10n,
  required DateTime wallNow,
}) {
  final before = isBeforeDayStart(wallNow);
  final cards = daily.cards;
  final dayPick = cards.focusTime.picks.first.branch;
  final nightPick = focusTimePickOf(
    cards,
    AppTimeOfDay.night,
    beforeDayStart: before,
  )?.card.picks.first.branch;
  final language = _languageCodeOf(l10n);
  final hanjaLabels = language != 'ko' && language != 'ja';
  final dayCells = [
    for (final branch in _dayBranches)
      TimeBandCell(
        label: _bandLabelOf(branch, names, hanjaLabels),
        period: AppTimeOfDay.day,
        picked: branch == dayPick,
      ),
  ];
  final nightCells = [
    for (final branch in _nightBranches)
      TimeBandCell(
        label: _bandLabelOf(branch, names, hanjaLabels),
        period: AppTimeOfDay.night,
        picked: branch == nightPick,
      ),
  ];
  final dayStart = _dayStart.inMinutes;
  final nightStart =
      dayStart + _hourBranchLength.inMinutes * _dayBranches.length;
  final bandStart = before ? nightStart : dayStart;
  final now = wallNow.hour * 60 + wallNow.minute;
  final elapsed = (now - bandStart) % _minutesPerDay;
  return TimeBand(
    cells: before ? [...nightCells, ...dayCells] : [...dayCells, ...nightCells],
    dayHead: l10n.todayLuckyTimeBandDay,
    nightHead: l10n.todayLuckyTimeBandNight,
    nowFraction: elapsed / _minutesPerDay,
    nowLabel: l10n.todayLuckyTimeBandNow(_clockText(now)),
    startTick: TimeBandTick(
      time: _clockText(bandStart),
      dayWord: before ? l10n.todayLuckyTimeBandYesterday : null,
    ),
    boundaryTick: TimeBandTick(
      time: _clockText(before ? dayStart : nightStart),
    ),
    endTick: TimeBandTick(
      time: _clockText(bandStart),
      dayWord: before ? null : l10n.todayLuckyTimeBandTomorrow,
    ),
    hanjaLabels: hanjaLabels,
  );
}

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
/// ([dailyCardSlotId], `<슬롯>#<카드>`)면 그 카드의 문장이고, 카드가 없거나 슬롯이 다르면 null입니다.
SlotText? dailySlotText(Daily daily, String slotId) {
  final cards = daily.cards;
  final cardMark = slotId.indexOf('#');
  if (cardMark >= 0) {
    final text = _cardText(cards, slotId.substring(cardMark + 1));
    return text?.slot == slotId.substring(0, cardMark) ? text : null;
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
    required this.iljinText,
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

  /// 날짜 머리의 일진 글자(`today.date.iljin`, 예 `庚申(경신)일`).
  final String iljinText;

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
    iljinText,
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
  LuckyItem() => [
    value.variant.name,
    value.name,
    value.value,
    value.explain.toJson(),
    value.element?.name,
    value.period?.name,
    value.word,
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

/// [daily]의 일진 글자(`todayDateIljin`). 간지 글자는 [pillarTextOf]입니다.
String iljinTextOf(Daily daily, GlossaryNames names, AppLocalizations l10n) =>
    l10n.todayDateIljin(pillarTextOf(daily.dayPillar, names));

/// [pillar]의 간지 글자: 한자 뒤 괄호에 독음을 붙이고(`庚申(경신)`), 천간이나 지지 독음이
/// 없으면 한자만 씁니다(오늘 날짜 머리, 일기 쓰기 날짜 블록). 독음 원천은 [GanjiReading](A133)이고
/// #1069 전에는 없어 한자만입니다.
String pillarTextOf(Pillar pillar, GlossaryNames? names) {
  final hanja = '${stemHanja(pillar.stem)}${branchHanja(pillar.branch)}';
  final stemReading = GanjiReading.stem(pillar.stem, names);
  final branchReading = GanjiReading.branch(pillar.branch, names);
  return stemReading == null || branchReading == null
      ? hanja
      : '$hanja($stemReading$branchReading)';
}

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
    iljinText: iljinTextOf(daily, names, l10n),
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

  /// 행운 항목. 시간은 낮 칩 하나입니다(V116).
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
    // 공유 이미지는 낮 칩 하나라(V116) 밤 칩을 고르지 않습니다.
    items: [
      for (final item in luckyItemsOf(
        daily,
        names,
        l10n,
        timezone,
        beforeDayStart: false,
      ))
        if (item.period != AppTimeOfDay.night) item,
    ],
    footer: l10n.sharePreviewImageFooter,
    reason: character.reason,
  );
}
