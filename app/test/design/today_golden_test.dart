import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/day_virtue_kind.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/today/color_pair_sheet_body.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/design/components/today/time_band.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

/// day-character: 네 변형 × 이유 있음(링크 포함)·없음.
Widget _dayCharacters() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    String name(DayKind kind) => switch (kind) {
      DayKind.yongsinDay => ja ? '良い日' : '좋은 날',
      DayKind.gwiinDay => ja ? '貴人の日' : '귀인의 날',
      DayKind.gisinDay => ja ? '忌神の日' : '기신의 날',
      DayKind.ordinaryDay => ja ? '普通の日' : '평범한 날',
    };
    final reason = RenderedText(
      segments: [
        Segment(
          text: ja ? '今日は気の流れがあなたを助けてくれる日です。' : '오늘은 기운의 흐름이 나를 도와주는 날이에요.',
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s16,
      children: [
        for (final kind in DayKind.values) ...[
          DayCharacter(
            variant: dayCharacterVariantOf(kind),
            label: name(kind),
            reason: reason,
            reasonTrailing: DepthLink.evidence(
              subject: ja ? '総運' : '총운',
              placement: DepthLinkPlacement.inlineEnd,
              onTap: () {},
            ),
          ),
          DayCharacter(variant: dayCharacterVariantOf(kind), label: name(kind)),
        ],
      ],
    );
  },
);

/// lucky-card golden의 네 변형 항목(집중 시간은 낮 칩과 밤 칩, V115, V116). 언어별로 값을 줍니다.
List<LuckyItem> _goldenLuckyItems({required bool ja}) {
  RenderedText text(String ko, String jp) =>
      RenderedText(segments: [Segment(text: ja ? jp : ko)]);
  return [
    LuckyItem(
      variant: LuckyCardVariant.color,
      name: ja ? 'ラッキーカラー' : '행운 색',
      value: ja ? '青' : '파랑',
      explain: text('물의 기운이 마음을 가라앉혀 줘요.', '水の気が心を落ち着かせてくれます。'),
      element: FiveElement.water,
    ),
    LuckyItem(
      variant: LuckyCardVariant.direction,
      name: ja ? 'ラッキー方位' : '행운 방향',
      value: ja ? '東' : '동',
      explain: text('약속 장소를 고른다면 동쪽이 좋아요.', '方位の説明文です。'),
    ),
    LuckyItem(
      variant: LuckyCardVariant.number,
      name: ja ? 'ラッキーナンバー' : '행운 숫자',
      value: '3',
      explain: text('3이 흐름을 열어 줘요.', '3が流れを開いてくれます。'),
    ),
    LuckyItem(
      variant: LuckyCardVariant.time,
      name: ja ? '昼の吉時' : '낮의 길한 시간',
      value: ja ? '15:30〜17:30' : '15:30~17:30',
      explain: text('오후 3시쯤 집중이 잘 돼요.', '午後3時ごろ集中しやすくなります。'),
      period: AppTimeOfDay.day,
    ),
    LuckyItem(
      variant: LuckyCardVariant.time,
      name: ja ? '夜の吉時' : '밤의 길한 시간',
      value: ja ? '01:30〜03:30' : '01:30~03:30',
      explain: text('새벽 1시쯤 마음이 차분해요.', '午前1時ごろ心が落ち着きます。'),
      period: AppTimeOfDay.night,
      word: ja ? '今夜' : '오늘 밤',
    ),
  ];
}

bool _isJa(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja';

/// lucky-card: 네 변형 칩 줄. 칸 폭 360에서 글자가 커지면 두 줄로 넘어갑니다.
Widget _luckyCard() => Builder(
  builder: (context) => LuckyCardRow(
    items: _goldenLuckyItems(ja: _isJa(context)),
    // 시트가 열려 있는 동안을 흉내 내려고 닫히지 않는 Future를 줍니다.
    onOpen: (_) => Completer<void>().future,
  ),
);

/// date-header: 오늘 화면의 날짜, 음력, 일진(독음), 덕일 알약(`hanja-tag` `compact` 길 톤, V119).
/// 덕 둘(천덕일, 월덕일), 덕 하나에 그 풀이 시트가 열린 동안(`selected`), 덕일 없는 날 순서입니다.
Widget _dateHeaders() => Builder(
  builder: (context) {
    final ja = _isJa(context);
    final l10n = AppLocalizations.of(context);
    final cheondeok = DateHeaderVirtue(
      glyph: HanjaGlyphs.forDayVirtue(DayVirtueKind.cheondeokDay)!,
      label: l10n.todayDateVirtueCheondeok,
      onTap: () {},
    );
    final woldeok = DateHeaderVirtue(
      glyph: HanjaGlyphs.forDayVirtue(DayVirtueKind.woldeokDay)!,
      label: l10n.todayDateVirtueWoldeok,
      onTap: () {},
    );
    DateHeader header(List<DateHeaderVirtue> virtues) => DateHeader(
      solar: ja ? '11月13日 金曜日' : '11월 13일 금요일',
      lunar: ja ? '旧暦 9月24日' : '음력 9월 24일',
      iljin: ja
          ? const IljinText(shown: '庚申（かのえさる）日', spoken: 'かのえさる日')
          : const IljinText(shown: '庚申(경신)일', spoken: '경신일'),
      virtues: virtues,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s24,
      children: [
        header([cheondeok, woldeok]),
        header([
          DateHeaderVirtue(
            glyph: woldeok.glyph,
            label: woldeok.label,
            selected: true,
            onTap: () {},
          ),
        ]),
        header(const []),
      ],
    );
  },
);

/// hanja-tag `compact`(알약 22)를 기본 크기(30) 옆에 둡니다. 길 톤 기본과 `selected`, 용어 톤입니다.
Widget _hanjaTagCompact() => Builder(
  builder: (context) {
    final label = AppLocalizations.of(context).todayDateVirtueCheondeok;
    final glyph = HanjaGlyphs.forDayVirtue(DayVirtueKind.cheondeokDay)!;
    Widget pair({
      HanjaTagTone tone = HanjaTagTone.good,
      HanjaTagVariant variant = HanjaTagVariant.normal,
    }) => Row(
      spacing: Space.s8,
      children: [
        for (final size in HanjaTagSize.values)
          HanjaTag(
            glyph: glyph,
            label: label,
            tone: tone,
            variant: variant,
            size: size,
            onTap: () {},
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.s12,
      children: [
        pair(),
        pair(variant: HanjaTagVariant.selected),
        pair(tone: HanjaTagTone.term),
      ],
    );
  },
);

/// 색이 둘인 날의 행운 칩 줄(D119 ②, V114): 색 칩이 두 칸 알약입니다.
Widget _luckyCardPair() => Builder(
  builder: (context) {
    final ja = _isJa(context);
    final items = _goldenLuckyItems(ja: ja);
    final color = items.first;
    return LuckyCardRow(
      items: [
        LuckyItem(
          variant: color.variant,
          name: color.name,
          value: color.value,
          explain: color.explain,
          element: color.element,
          secondColor: LuckySecondColor(
            element: FiveElement.earth,
            value: ja ? '黄' : '노랑',
            explain: RenderedText(
              segments: [
                Segment(
                  text: ja ? '原典の解釈では今日は黄も合います。' : '원전의 해석에 따르면 오늘은 노랑도 어울려요.',
                ),
              ],
            ),
          ),
        ),
        ...items.skip(1),
      ],
      onOpen: (_) => Completer<void>().future,
    );
  },
);

/// 색이 둘인 날 행운 색 시트 본문(V114, V118): 한 줄 안내, 색마다 견본과 이름, 풀이, 근거 진입점.
Widget _colorPairSheet() => Builder(
  builder: (context) {
    final ja = _isJa(context);
    final l10n = AppLocalizations.of(context);
    RenderedText text(String value) =>
        RenderedText(segments: [Segment(text: value)]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s20),
      child: ColorPairSheetBody(
        title: ja ? 'ラッキーカラー' : '행운 색',
        intro: l10n.todayLuckyColorPairIntro,
        sections: [
          ColorPairSection(
            element: FiveElement.water,
            name: ja ? '黒' : '검정',
            body: text(
              ja ? 'あなたの四柱のバランスから見ると黒がよく合います。' : '내 사주의 균형으로 보면 검정이 잘 맞아요.',
            ),
            bodySlotId: SlotIds.todayLuckyColorBody,
            onEvidence: () {},
          ),
          ColorPairSection(
            element: FiveElement.earth,
            name: ja ? '黄' : '노랑',
            body: text(ja ? '原典の解釈では今日は黄も合います。' : '원전의 해석에 따르면 오늘은 노랑도 어울려요.'),
            bodySlotId: SlotIds.todayLuckyColorSecondBody,
            onEvidence: () {},
          ),
        ],
      ),
    );
  },
);

/// 시간 칩 시트의 24시간 띠(V117, V118 ③, V124). 위는 낮 구간부터(낮 칩을 열어 신시는 연 칩
/// 고리, 밤 축시는 다른 칩 고리, 지금 19:30), 아래는 낮 구간 시작 전(밤 칩을 열어 축시가 연 칩
/// 고리, 지금이 띠 밖이라 지금 줄 없음)입니다.
Widget _timeBands() => Builder(
  builder: (context) {
    final ja = _isJa(context);
    final l10n = AppLocalizations.of(context);
    final dayNames = (ja ? '辰巳午未申酉戌' : '진사오미신유술').split('');
    final nightNames = (ja ? '亥子丑寅卯' : '해자축인묘').split('');
    List<TimeBandCell> block(
      List<String> names,
      AppTimeOfDay period,
      int pickIndex,
      AppTimeOfDay opened,
    ) => [
      for (final (index, label) in names.indexed)
        TimeBandCell(
          label: label,
          period: period,
          pick: TimeBandPick.of(
            period,
            opened: opened,
            chosen: index == pickIndex,
          ),
        ),
    ];
    final fromDay = TimeBand(
      cells: [
        ...block(dayNames, AppTimeOfDay.day, 4, AppTimeOfDay.day),
        ...block(nightNames, AppTimeOfDay.night, 2, AppTimeOfDay.day),
      ],
      dayHead: l10n.todayLuckyTimeBandDay,
      nightHead: l10n.todayLuckyTimeBandNight,
      nowFraction: 0.5,
      nowLabel: l10n.todayLuckyTimeBandNow('19:30'),
      startTick: const TimeBandTick(time: '07:30'),
      boundaryTick: const TimeBandTick(time: '21:30'),
      endTick: TimeBandTick(
        time: '07:30',
        dayWord: l10n.todayLuckyTimeBandTomorrow,
      ),
    );
    final beforeDay = TimeBand(
      cells: [
        ...block(nightNames, AppTimeOfDay.night, 2, AppTimeOfDay.night),
        ...block(dayNames, AppTimeOfDay.day, 4, AppTimeOfDay.night),
      ],
      dayHead: l10n.todayLuckyTimeBandDay,
      nightHead: l10n.todayLuckyTimeBandNight,
      nowFraction: null,
      nowLabel: l10n.todayLuckyTimeBandNow('07:40'),
      startTick: TimeBandTick(
        time: '21:30',
        dayWord: l10n.todayLuckyTimeBandYesterday,
      ),
      boundaryTick: const TimeBandTick(time: '07:30'),
      endTick: const TimeBandTick(time: '21:30'),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s32,
        children: [fromDay, beforeDay],
      ),
    );
  },
);

/// guide-question-card: 상태별 카드. 질문은 server가 렌더한 문장이라 언어별로 줍니다.
Widget _guideQuestionCard(GuideQuestionState state) => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final written = state != GuideQuestionState.before;
    // full은 버튼 글자가 이유를 말하므로 실제 문구(`todayGuideCtaFull`)를 씁니다.
    final fullLabel = AppLocalizations.of(context).todayGuideCtaFull;
    return GuideQuestionCard(
      state: state,
      eyebrow: ja ? '今日の質問' : '오늘의 질문',
      question: RenderedText(
        segments: [
          Segment(
            text: ja ? '今日、いちばん心に残った場面は何でしたか?' : '오늘 가장 오래 마음에 남은 장면은 무엇인가요?',
          ),
        ],
      ),
      actionLabel: state == GuideQuestionState.full
          ? fullLabel
          : ja
          ? (written ? '書いた日記を見る' : '日記を書く')
          : (written ? '쓴 일기 보기' : '일기 쓰기'),
      onAction: () {},
    );
  },
);

/// share-image: 한 변형. 격자 칸 폭(336)에 맞춰 줄여 담고, 다크·글자 배율 칸도 같은 그림입니다.
Widget _shareImage(ShareImageVariant variant) => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    RenderedText text(String ko, String jp) =>
        RenderedText(segments: [Segment(text: ja ? jp : ko)]);
    return FittedBox(
      alignment: Alignment.topLeft,
      child: ShareImage(
        variant: variant,
        date: ja ? '10月15日 木曜日' : '10월 15일 목요일',
        dayKind: DayKind.yongsinDay,
        dayKindLabel: ja ? '良い日' : '좋은 날',
        sentence: text(
          '오늘은 기운의 흐름이 나를 도와주는 날이에요. 먼저 연락해 보세요. 좋은 소식이 올 거예요.',
          '今日は気の流れがあなたを助けてくれる日です。まずは連絡してみましょう。良い知らせが届きます。',
        ),
        reason: text('기운의 흐름이 나를 도와주는 날이라서요.', '気の流れがあなたを助けてくれる日だからです。'),
        items: [
          LuckyItem(
            variant: LuckyCardVariant.color,
            name: ja ? 'ラッキーカラー' : '행운 색',
            value: ja ? '青' : '파랑',
            explain: text('물의 기운이 마음을 가라앉혀 줘요.', '水の気が心を落ち着かせてくれます。'),
            element: FiveElement.water,
          ),
          LuckyItem(
            variant: LuckyCardVariant.direction,
            name: ja ? 'ラッキー方位' : '행운 방향',
            value: ja ? '東' : '동',
            explain: text('약속 장소를 고른다면 동쪽이 좋아요.', '方位の説明文です。'),
          ),
          LuckyItem(
            variant: LuckyCardVariant.number,
            name: ja ? 'ラッキーナンバー' : '행운 숫자',
            value: '3',
            explain: text('3이 흐름을 열어 줘요.', '3が流れを開いてくれます。'),
          ),
          LuckyItem(
            variant: LuckyCardVariant.time,
            name: ja ? '昼の吉時' : '낮의 길한 시간',
            value: ja ? '15:30〜17:30' : '15:30~17:30',
            explain: text('오후 3시쯤 집중이 잘 돼요.', '午後3時ごろ集中しやすくなります。'),
            period: AppTimeOfDay.day,
          ),
          LuckyItem(
            variant: LuckyCardVariant.time,
            name: ja ? '夜の吉時' : '밤의 길한 시간',
            value: ja ? '01:30〜03:30' : '01:30~03:30',
            explain: text('새벽 1시쯤 마음이 차분해요.', '午前1時ごろ心が落ち着きます。'),
            period: AppTimeOfDay.night,
            word: ja ? '今夜' : '오늘 밤',
          ),
        ],
        footer: ja ? '命理日記' : '명리일기',
      ),
    );
  },
);

/// 로고 그림(PNG)이 비동기로 올라오는 것을 기다립니다.
Future<void> _settleLogo(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
  await tester.pump();
}

void main() {
  goldenTest('day-character: 네 변형 × 이유 있음·없음', (tester) async {
    await goldenMatrix(tester, 'today_day_character', _dayCharacters);
  });

  goldenTest('lucky-card: 닫힘(네 변형 칩 줄)', (tester) async {
    await goldenMatrix(tester, 'today_lucky_card_closed', _luckyCard);
  });

  goldenTest('lucky-card: 열림(행운 색 설명)', (tester) async {
    await goldenMatrix(
      tester,
      'today_lucky_card_open',
      _luckyCard,
      settle: (tester) async {
        await tester.pump();
        // 칸마다 행운 색 칩을 눌러 열림 테두리를 그립니다.
        final chips = find.byKey(LuckyCardRow.chipKey(LuckyCardVariant.color));
        for (var i = 0; i < chips.evaluate().length; i++) {
          await tester.tapAt(tester.getCenter(chips.at(i)));
        }
        await tester.pumpAndSettle();
      },
    );
  });

  goldenTest('lucky-card: 색이 둘인 날 두 칸 알약 닫힘·열림', (tester) async {
    await goldenMatrix(tester, 'today_lucky_card_pair_closed', _luckyCardPair);
    await goldenMatrix(
      tester,
      'today_lucky_card_pair_open',
      _luckyCardPair,
      settle: (tester) async {
        await tester.pump();
        // 두 칸 알약의 첫 칸을 누릅니다(가운데 세로선은 누르는 자리가 아님).
        final chips = find.byKey(LuckyChip.pairHalfKey(0));
        for (var i = 0; i < chips.evaluate().length; i++) {
          await tester.tapAt(tester.getCenter(chips.at(i)));
        }
        await tester.pumpAndSettle();
      },
    );
  });

  goldenTest('lucky-card: 두 색 시트 본문', (tester) async {
    await goldenMatrix(tester, 'today_color_pair_sheet', _colorPairSheet);
  });

  goldenTest('lucky-card: 시간 칩 시트 24시간 띠(연 칩·다른 칩 고리, 지금 줄)', (tester) async {
    await goldenMatrix(tester, 'today_time_band', _timeBands);
  });

  goldenTest('date-header: 덕일 둘·열린 덕·덕일 없음(일진 독음)', (tester) async {
    await goldenMatrix(tester, 'today_date_header', _dateHeaders);
  });

  goldenTest('hanja-tag: compact와 기본 크기(길 톤·selected·용어 톤)', (tester) async {
    await goldenMatrix(tester, 'today_hanja_tag_compact', _hanjaTagCompact);
  });

  goldenTest('guide-question-card: before(일기 쓰기 전)', (tester) async {
    await goldenMatrix(
      tester,
      'today_guide_question_card_before',
      () => _guideQuestionCard(GuideQuestionState.before),
    );
  });

  goldenTest('guide-question-card: after(일기 쓴 뒤, 도장)', (tester) async {
    await goldenMatrix(
      tester,
      'today_guide_question_card_after',
      () => _guideQuestionCard(GuideQuestionState.after),
    );
  });

  goldenTest('guide-question-card: full(상한을 채운 날, 도장 유지·버튼 disabled)', (
    tester,
  ) async {
    await goldenMatrix(
      tester,
      'today_guide_question_card_full',
      () => _guideQuestionCard(GuideQuestionState.full),
    );
  });

  for (final variant in ShareImageVariant.values) {
    goldenTest('share-image: ${variant.name}(라이트 고정)', (tester) async {
      await goldenMatrix(
        tester,
        'today_share_image_${variant.name}',
        () => _shareImage(variant),
        settle: _settleLogo,
      );
    });
  }
}
