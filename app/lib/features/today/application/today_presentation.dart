import 'dart:convert';

import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/direction.dart';
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';

// 그날 응답(`Daily`)을 화면에 보일 값으로 바꾸는 한 곳입니다(결정 A22·A27).
// 계약 필드가 늘면 화면이 아니라 이 파일만 고칩니다. 오늘 화면과 계획 4 `day-sheet`,
// 공유 미리보기가 함께 씁니다.

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

  /// 이유 한 줄. 계약에 `character.reason` 필드가 아직 없어 늘 null입니다(결정 A22).
  final RenderedText? reason;
}

/// [daily]의 날의 성격 줄. 이름은 ARB(`dayKind*`)에서 고릅니다(A20 ①).
///
/// 이유 줄은 계약에 필드가 생기면 여기서 채웁니다(A22: 그 전에는 자리도 남기지 않음).
DayCharacterContent dayCharacterOf(Daily daily, AppLocalizations l10n) =>
    DayCharacterContent(
      variant: dayCharacterVariantOf(daily.dayKind),
      label: dayKindName(l10n, daily.dayKind),
    );

/// 행운 방향 이름(임시 ARB `direction*`, 결정 A27).
String directionName(AppLocalizations l10n, Direction direction) =>
    switch (direction) {
      Direction.n => l10n.directionN,
      Direction.ne => l10n.directionNe,
      Direction.e => l10n.directionE,
      Direction.se => l10n.directionSe,
      Direction.s => l10n.directionS,
      Direction.sw => l10n.directionSw,
      Direction.w => l10n.directionW,
      Direction.nw => l10n.directionNw,
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

/// `time_unknown` notice의 문장 조각 글자를 이은 것. 없으면 null입니다.
///
/// 화면 상태가 있는 notice는 이것뿐이고, 나머지는 계획 6에서 다룹니다.
String? timeUnknownNoticeOf(Daily daily) {
  for (final notice in daily.notices) {
    if (notice.code == NoticeCode.timeUnknown) {
      return notice.text.segments.map((s) => s.text).join();
    }
  }
  return null;
}

/// 화면에 보이는 내용의 서명. 캐시 → server 응답으로 바뀔 때 보이는 내용이 같은지 비교합니다.
///
/// 날의 성격, 총운 문장, 행운 값과 설명, 가이드 질문, 시간 모름 안내만 담습니다. 보이지 않는
/// 필드(`evidenceAccess`, `evidence`, `reaction`, 규칙 버전 등)만 바뀌면 같은 서명이라 내용이
/// 다시 스미지 않습니다. 화면에 새 필드를 그리면 여기에도 더합니다(A22). 생성 모델의 `==`는
/// 목록을 참조로 비교하므로 JSON 글자로 비교합니다.
String dailySignature(Daily daily) {
  final cards = daily.cards;
  return jsonEncode({
    'dayKind': daily.dayKind.value,
    'head': daily.fortune.head.text.toJson(),
    'tag': daily.fortune.tag?.text.toJson(),
    'color': [cards.color.element.value, cards.color.text.text.toJson()],
    'direction': [
      cards.direction.direction.value,
      cards.direction.text.text.toJson(),
    ],
    'number': [cards.number.number, cards.number.text.text.toJson()],
    'focusTime': [
      for (final pick in cards.focusTime.picks)
        [
          pick.start.toUtc().toIso8601String(),
          pick.end.toUtc().toIso8601String(),
        ],
      cards.focusTime.text.text.toJson(),
    ],
    'guide': daily.guide.text.toJson(),
    'timeUnknown': timeUnknownNoticeOf(daily),
  });
}
