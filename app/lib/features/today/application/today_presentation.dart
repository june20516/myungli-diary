import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;
import 'package:intl/intl.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/direction.dart';
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/notice_text.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

// 그날 응답(`Daily`)을 화면에 보일 값으로 바꾸는 한 곳입니다(결정 A22·A27).
// 계약 필드가 늘면 화면이 아니라 이 파일만 고칩니다. 오늘 화면과 계획 4 `day-sheet`,
// 공유 미리보기, 풀이·근거 시트(슬롯별 오늘 그런 이유·근거, [dailySlotText])가 함께 씁니다.
// A22는 draft.4로 해제되어 계약의 문장 필드를 모두 그리고, 원고가 없어 server가 생략한
// 선택 문장만 자리 없이 건너뜁니다.

/// 오늘 화면 행운 설명 상자의 슬롯 id.
const Map<LuckyCardVariant, String> todayLuckySlotIds = {
  LuckyCardVariant.color: SlotIds.todayLuckyColorBody,
  LuckyCardVariant.direction: SlotIds.todayLuckyDirectionBody,
  LuckyCardVariant.number: SlotIds.todayLuckyNumberBody,
  LuckyCardVariant.time: SlotIds.todayLuckyTimeBody,
};

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

/// 집중 시간 칸을 [timezone](프로필 시간대) 현지 `HH:mm–HH:mm`으로 쓰고, 둘이면 ` · `로 잇습니다.
///
/// 응답 시각은 오프셋이 붙어 오지만 같은 순간이면 UTC로 바뀌어도 같은 값입니다(결정 A27).
String formatFocusRange(List<FocusSlot> picks, String timezone) => [
  for (final pick in picks)
    '${_hourMinute(pick.start, timezone)}–${_hourMinute(pick.end, timezone)}',
].join(' · ');

/// [daily]의 행운 항목 4개(색·방향·숫자·시간, 결정 A27).
///
/// 색 이름은 glossary `color.<오행>`(없으면 값 id 그대로), 방향은 임시 ARB, 숫자는 그대로,
/// 시간은 [formatFocusRange]입니다. 색 칩의 견본 색은 칩이 테마에서 고릅니다.
List<LuckyItem> luckyItemsOf(
  Daily daily,
  GlossaryNames names,
  AppLocalizations l10n,
  String timezone,
) {
  final cards = daily.cards;
  final element = cards.color.element;
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
      name: l10n.todayLuckyTimeName,
      value: formatFocusRange(cards.focusTime.picks, timezone),
      explain: cards.focusTime.text.text,
    ),
  ];
}

/// [daily]에서 writing 슬롯 id가 [slotId]인 문장. 응답에 없는 슬롯이면 null입니다.
///
/// 날의 성격 이유·총운(첫 문장·태그 문장)·가이드 질문·행운 카드 문장을 찾습니다. 풀이 시트는
/// 이 문장의 `todayReason`(오늘 그런 이유)을, 근거 시트는 `evidence`를 씁니다.
SlotText? dailySlotText(Daily daily, String slotId) {
  final cards = daily.cards;
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

/// `time_unknown` notice의 배너 문장([noticeTextOf]). 없으면 null입니다.
///
/// 화면 상태가 있는 notice는 이것뿐이고, 나머지는 계획 6에서 다룹니다.
String? timeUnknownNoticeOf(Daily daily, AppLocalizations l10n) {
  for (final notice in daily.notices) {
    if (notice.code == NoticeCode.timeUnknown) {
      return noticeTextOf(notice, l10n);
    }
  }
  return null;
}

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

/// [text]의 조각 글자를 이어 보면 비었거나 공백뿐인지. 빈 문장은 자리 없이 건너뜁니다(A22 남은 규칙).
bool isBlankText(RenderedText text) =>
    text.segments.map((segment) => segment.text).join().trim().isEmpty;

/// 오늘 화면이 그리는 값 묶음. 화면은 이 값으로만 내용을 그립니다.
///
/// 값 동등성(`==`)이 있어 캐시 → server 응답으로 바뀔 때 보이는 내용이 같은지 이 값으로
/// 비교합니다(`SeepOnChange.changeKey`). 보이지 않는 필드(`evidenceAccess`, `evidence`,
/// `reaction`, 규칙 버전 등)는 담지 않으므로 그것만 바뀌면 같은 값입니다. 계약 필드가 늘어
/// 화면에 그리면 이 클래스에 필드를 더하고 [_props]에 넣습니다. 비교 방식은 [_canonical]
/// 한 곳이 정하고, 모르는 타입이 들어오면 던지므로 빠뜨린 정규화는 테스트에서 드러납니다.
@immutable
final class TodayDisplay {
  /// 오늘 화면 값을 만듭니다.
  const new({
    required this.character,
    required this.characterReasonSlot,
    required this.timeUnknown,
    required this.head,
    required this.headReactable,
    required this.tag,
    required this.lucky,
    required this.guide,
  });

  /// 날의 성격 줄.
  final DayCharacterContent character;

  /// 날의 성격 이유가 채우는 writing 슬롯 id(이유 줄 끝 근거 보기가 근거 시트에 넘김).
  final String characterReasonSlot;

  /// 시간 모름 안내 글. 없으면 null입니다.
  final String? timeUnknown;

  /// 총운 첫 문장.
  final SentenceLine head;

  /// 총운 첫 문장에 반응 버튼을 두는지(`reactable`).
  final bool headReactable;

  /// 대표 태그 문장. 없으면 null입니다.
  final SentenceLine? tag;

  /// 행운 항목 4개.
  final List<LuckyItem> lucky;

  /// 가이드 질문.
  final RenderedText guide;

  /// 동등성에 쓰는 필드 목록. 화면에 그리는 필드는 모두 여기에 있습니다.
  List<Object?> get _props => [
    character,
    characterReasonSlot,
    timeUnknown,
    head,
    headReactable,
    tag,
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
  DayCharacterContent() => [
    value.variant.name,
    value.label,
    value.reason?.toJson(),
  ],
  LuckyItem() => [
    value.variant.name,
    value.name,
    value.value,
    value.explain.toJson(),
    value.element?.name,
  ],
  Iterable<Object?>() => [for (final item in value) _canonical(item)],
  _ => throw ArgumentError.value(value, 'value', '비교 방식을 정하지 않은 타입입니다'),
};

/// [daily]를 오늘 화면 값으로 바꿉니다. 이름은 [names]·[l10n], 시각은 [timezone](프로필 시간대)입니다.
TodayDisplay todayDisplayOf(
  Daily daily,
  GlossaryNames names,
  AppLocalizations l10n,
  String timezone,
) {
  final tag = daily.fortune.tag;
  return TodayDisplay(
    character: dayCharacterOf(daily, l10n),
    characterReasonSlot: daily.characterReason.slot,
    timeUnknown: timeUnknownNoticeOf(daily, l10n),
    head: SentenceLine(
      text: daily.fortune.head.text,
      slot: daily.fortune.head.slot,
    ),
    headReactable: daily.fortune.head.reactable,
    tag: tag == null ? null : SentenceLine(text: tag.text, slot: tag.slot),
    lucky: luckyItemsOf(daily, names, l10n, timezone),
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

  /// 행운 항목.
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
    items: luckyItemsOf(daily, names, l10n, timezone),
    footer: l10n.sharePreviewImageFooter,
    reason: character.reason,
  );
}
