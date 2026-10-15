import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
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
            reasonTrailing: DepthLink(
              variant: DepthLinkVariant.inlineEnd,
              label: ja ? '根拠を見る' : '근거 보기',
              onTap: () {},
            ),
          ),
          DayCharacter(variant: dayCharacterVariantOf(kind), label: name(kind)),
        ],
      ],
    );
  },
);

/// lucky-card: 네 변형 칩 줄. 칸 폭 360에서 글자가 커지면 두 줄로 넘어갑니다.
Widget _luckyCard() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    RenderedText text(String ko, String jp) =>
        RenderedText(segments: [Segment(text: ja ? jp : ko)]);
    return LuckyCardRow(
      items: [
        LuckyItem(
          variant: LuckyCardVariant.color,
          name: ja ? 'ラッキーカラー' : '행운 색',
          value: ja ? '青' : '파랑',
          explain: text('물의 기운이 마음을 가라앉혀 줘요.', '水の気が心を落ち着かせてくれます。'),
          swatch: const Color(0xFF3B6FB6),
        ),
        LuckyItem(
          variant: LuckyCardVariant.direction,
          name: ja ? 'ラッキー方位' : '행운 방향',
          value: ja ? '東' : '동쪽',
          explain: text('동쪽에서 좋은 기운이 들어와요.', '東から良い気が入ってきます。'),
        ),
        LuckyItem(
          variant: LuckyCardVariant.number,
          name: ja ? 'ラッキーナンバー' : '행운 숫자',
          value: '3',
          explain: text('3이 흐름을 열어 줘요.', '3が流れを開いてくれます。'),
        ),
        LuckyItem(
          variant: LuckyCardVariant.time,
          name: ja ? '集中できる時間' : '집중하기 좋은 시간',
          value: ja ? '午後3時' : '오후 3시',
          explain: text('오후 3시쯤 집중이 잘 돼요.', '午後3時ごろ集中しやすくなります。'),
        ),
      ],
    );
  },
);

/// guide-question-card: 상태별 카드. 질문은 server가 렌더한 문장이라 언어별로 줍니다.
Widget _guideQuestionCard(GuideQuestionState state) => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final written = state == GuideQuestionState.after;
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
      actionLabel: ja
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
            swatch: const Color(0xFF3B6FB6),
          ),
          LuckyItem(
            variant: LuckyCardVariant.direction,
            name: ja ? 'ラッキー方位' : '행운 방향',
            value: ja ? '東' : '동쪽',
            explain: text('동쪽에서 좋은 기운이 들어와요.', '東から良い気が入ってきます。'),
          ),
          LuckyItem(
            variant: LuckyCardVariant.number,
            name: ja ? 'ラッキーナンバー' : '행운 숫자',
            value: '3',
            explain: text('3이 흐름을 열어 줘요.', '3が流れを開いてくれます。'),
          ),
          LuckyItem(
            variant: LuckyCardVariant.time,
            name: ja ? '集中できる時間' : '집중하기 좋은 시간',
            value: ja ? '午後3時' : '오후 3시',
            explain: text('오후 3시쯤 집중이 잘 돼요.', '午後3時ごろ集中しやすくなります。'),
          ),
        ],
        footer: ja ? '命理日記' : '명리일기',
      ),
    );
  },
);

/// 로고(SVG)가 비동기로 올라오는 것을 기다립니다.
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
        // 칸마다 행운 색 칩을 눌러 설명을 엽니다.
        final chips = find.byKey(LuckyCardRow.chipKey(LuckyCardVariant.color));
        for (var i = 0; i < chips.evaluate().length; i++) {
          await tester.tapAt(tester.getCenter(chips.at(i)));
        }
        await tester.pumpAndSettle();
      },
    );
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
