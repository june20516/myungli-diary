import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/today/color_pair_sheet_body.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/design/components/today/tag_sentence_list.dart';
import 'package:myungli_diary/design/components/today/time_band.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

final RenderedText _guideQuestion = RenderedText(
  segments: [Segment(text: '오늘 가장 오래 마음에 남은 장면은 무엇인가요?')],
);

/// `full`은 그날 일기를 다 채워 버튼이 꺼진 모양입니다(D83 ②).
Widget _guideCard(GuideQuestionState state, {VoidCallback? onAction}) =>
    GuideQuestionCard(
      state: state,
      eyebrow: '오늘의 질문',
      question: _guideQuestion,
      actionLabel: switch (state) {
        GuideQuestionState.before => '일기 쓰기',
        GuideQuestionState.after => '새 일기 쓰기',
        GuideQuestionState.full => '오늘은 충분히 썼어요',
      },
      onAction: onAction ?? () {},
    );

final RenderedText _reason = RenderedText(
  segments: [Segment(text: '오늘은 기운의 흐름이 나를 도와주는 날이에요.')],
);

final List<LuckyItem> _luckyItems = [
  LuckyItem(
    variant: LuckyCardVariant.color,
    name: '행운 색',
    value: '파랑',
    explain: RenderedText(segments: [Segment(text: '물의 기운이 마음을 가라앉혀 줘요.')]),
    element: FiveElement.water,
  ),
  LuckyItem(
    variant: LuckyCardVariant.direction,
    name: '행운 방향',
    value: '동',
    explain: RenderedText(segments: [Segment(text: '약속 장소를 고른다면 동쪽이 좋아요.')]),
  ),
  LuckyItem(
    variant: LuckyCardVariant.number,
    name: '행운 숫자',
    value: '3',
    explain: RenderedText(segments: [Segment(text: '3이 흐름을 열어 줘요.')]),
  ),
  // 집중 시간은 낮 칩 하나와 밤 칩 하나입니다(V115, V116).
  LuckyItem(
    variant: LuckyCardVariant.time,
    name: '낮의 길한 시간',
    value: '15:30~17:30',
    explain: RenderedText(segments: [Segment(text: '오후 3시쯤 집중이 잘 돼요.')]),
    period: AppTimeOfDay.day,
  ),
  LuckyItem(
    variant: LuckyCardVariant.time,
    name: '밤의 길한 시간',
    value: '01:30~03:30',
    explain: RenderedText(segments: [Segment(text: '새벽 1시쯤 마음이 차분해요.')]),
    period: AppTimeOfDay.night,
    word: '오늘 밤',
  ),
];

/// 색이 둘인 날(D119 ②)의 칩 줄: 색 칩 하나가 두 칸 알약입니다(V114).
final List<LuckyItem> _pairLuckyItems = [
  LuckyItem(
    variant: LuckyCardVariant.color,
    name: '행운 색',
    value: '검정',
    explain: RenderedText(
      segments: [Segment(text: '내 사주의 균형으로 보면 검정이 잘 맞아요.')],
    ),
    element: FiveElement.water,
    secondColor: LuckySecondColor(
      element: FiveElement.earth,
      value: '노랑',
      explain: RenderedText(
        segments: [Segment(text: '원전의 해석에 따르면 오늘은 노랑도 어울려요.')],
      ),
    ),
  ),
  ..._luckyItems.skip(1),
];

/// 색이 둘인 날 행운 색 시트 본문 견본(`colorPairSheet`).
Widget _colorPairSheet() {
  final first = _pairLuckyItems.first;
  final second = first.secondColor!;
  return ColorPairSheetBody(
    title: first.name,
    intro: '오늘은 추천 색이 두 개예요',
    sections: [
      ColorPairSection(
        element: first.element!,
        name: first.value,
        body: first.explain,
        bodySlotId: SlotIds.todayLuckyColorBody,
        onEvidence: () {},
      ),
      ColorPairSection(
        element: second.element,
        name: second.value,
        body: second.explain,
        bodySlotId: SlotIds.todayLuckyColorSecondBody,
        onEvidence: () {},
      ),
    ],
  );
}

/// 시간 칩 시트의 24시간 띠 견본(낮 신시, 밤 축시 고름). 07:30 전 견본은 밤 칩, 그 뒤 견본은
/// 낮 칩으로 연 모습이라 연 칩 시진이 굵은 고리입니다(V124).
TimeBand _timeBand({required bool beforeDayStart}) {
  final opened = beforeDayStart ? AppTimeOfDay.night : AppTimeOfDay.day;
  final day = [
    for (final (index, label) in '진사오미신유술'.split('').indexed)
      TimeBandCell(
        label: label,
        period: AppTimeOfDay.day,
        pick: TimeBandPick.of(
          AppTimeOfDay.day,
          opened: opened,
          chosen: index == 4,
        ),
      ),
  ];
  final night = [
    for (final (index, label) in '해자축인묘'.split('').indexed)
      TimeBandCell(
        label: label,
        period: AppTimeOfDay.night,
        pick: TimeBandPick.of(
          AppTimeOfDay.night,
          opened: opened,
          chosen: index == 2,
        ),
      ),
  ];
  return TimeBand(
    cells: beforeDayStart ? [...night, ...day] : [...day, ...night],
    dayHead: '낮',
    nightHead: '밤',
    nowFraction: beforeDayStart ? 160 / 1440 : 270 / 1440,
    nowLabel: beforeDayStart ? '지금 00:10' : '지금 12:00',
    startTick: TimeBandTick(
      time: beforeDayStart ? '21:30' : '07:30',
      dayWord: beforeDayStart ? '어제' : null,
    ),
    boundaryTick: TimeBandTick(time: beforeDayStart ? '07:30' : '21:30'),
    endTick: TimeBandTick(
      time: beforeDayStart ? '21:30' : '07:30',
      dayWord: beforeDayStart ? null : '내일',
    ),
  );
}

String _name(DayKind kind) => switch (kind) {
  DayKind.yongsinDay => '좋은 날',
  DayKind.gwiinDay => '귀인의 날',
  DayKind.gisinDay => '기신의 날',
  DayKind.ordinaryDay => '평범한 날',
};

ShareImage _shareImage(ShareImageVariant variant) => ShareImage(
  variant: variant,
  date: '10월 15일 목요일',
  dayKind: DayKind.yongsinDay,
  dayKindLabel: '좋은 날',
  sentence: RenderedText(
    segments: [
      Segment(text: '오늘은 기운의 흐름이 나를 도와주는 날이에요. 먼저 연락해 보세요. 좋은 소식이 올 거예요.'),
    ],
  ),
  reason: _reason,
  items: _luckyItems,
  footer: '명리일기',
);

/// 오늘 카탈로그: day-character(good·gwiin·gisin·ordinary),
/// lucky-card(네 변형 칩 줄·대표 태그 칩), guide-question-card,
/// 가로 360 칸에 놓는 무대.
Widget _stage360(Widget child) =>
    Stage(child: SizedBox(width: 360, child: child));

/// share-image(story·feed·square와 비율 전환 미리보기).
final WidgetbookFolder todayDirectory = WidgetbookFolder(
  name: '오늘',
  children: [
    WidgetbookFolder(
      name: 'date-header',
      children: [
        WidgetbookComponent(
          name: 'DateHeader',
          useCases: [
            WidgetbookUseCase(
              name: 'today: 날짜, 음력, 일진',
              builder: (context) => _stage360(
                const DateHeader(
                  solar: '10월 13일 화요일',
                  lunar: '음력 8월 24일',
                  iljin: IljinText(shown: '癸未(계미)일', spoken: '계미일'),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'today: 덕일 둘(천덕일, 월덕일)',
              builder: (context) => _stage360(
                DateHeader(
                  solar: '10월 19일 월요일',
                  lunar: '음력 8월 30일',
                  iljin: const IljinText(shown: '丙寅(병인)일', spoken: '병인일'),
                  virtues: [
                    DateHeaderVirtue(glyph: '德', label: '천덕일', onTap: () {}),
                    DateHeaderVirtue(
                      glyph: '德',
                      label: '월덕일',
                      selected: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'day-sheet: 날짜와 음력',
              builder: (context) => _stage360(
                const DateHeader(solar: '10월 13일 화요일', lunar: '음력 8월 24일'),
              ),
            ),
            WidgetbookUseCase(
              name: '음력 없음',
              builder: (context) => _stage360(
                const DateHeader(
                  solar: '10월 13일 화요일',
                  iljin: IljinText(shown: '癸未(계미)일', spoken: '계미일'),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'loading',
              builder: (context) =>
                  _stage360(DateHeader.skeleton(solar: '10월 13일 화요일')),
            ),
          ],
        ),
      ],
    ),
    WidgetbookFolder(
      name: 'tag-sentence-list',
      children: [
        WidgetbookComponent(
          name: 'TagSentenceList',
          useCases: [
            WidgetbookUseCase(
              name: '문장 두 줄',
              builder: (context) => _stage360(
                TagSentenceList(
                  title: '이 기운에서 나온 오늘 문장',
                  emptyText: '오늘은 이 기운으로 정해진 문장이 없어요.',
                  diaryLinkLabel: '천을귀인 태그가 붙은 일기 보기',
                  onDiaryLink: () {},
                  items: [
                    TagSentence(
                      kindLabel: '보조 문장',
                      text: RenderedText(
                        segments: [Segment(text: '어려울 때 도와주는 사람이 곁에 오는 날이에요.')],
                      ),
                    ),
                    TagSentence(kindLabel: '오늘의 질문', text: _guideQuestion),
                  ],
                ),
              ),
            ),
            WidgetbookUseCase(
              name: '문장 없음',
              builder: (context) => _stage360(
                TagSentenceList(
                  title: '이 기운에서 나온 오늘 문장',
                  emptyText: '오늘은 이 기운으로 정해진 문장이 없어요.',
                  diaryLinkLabel: '천을귀인 태그가 붙은 일기 보기',
                  onDiaryLink: () {},
                  items: const [],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    WidgetbookFolder(
      name: 'day-character',
      children: [
        for (final kind in DayKind.values)
          WidgetbookComponent(
            name: dayCharacterVariantOf(kind).name,
            useCases: [
              WidgetbookUseCase(
                name: '이유 + 근거 링크',
                builder: (context) => Stage(
                  child: SizedBox(
                    width: 360,
                    child: DayCharacter(
                      variant: dayCharacterVariantOf(kind),
                      label: _name(kind),
                      reason: _reason,
                      reasonTrailing: DepthLink(
                        variant: DepthLinkVariant.inlineEnd,
                        label: '근거 보기',
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: '배지만',
                builder: (context) => Stage(
                  child: DayCharacter(
                    variant: dayCharacterVariantOf(kind),
                    label: _name(kind),
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
    WidgetbookFolder(
      name: 'lucky-card',
      children: [
        WidgetbookComponent(
          name: 'LuckyCardRow',
          useCases: [
            WidgetbookUseCase(
              name: '누르면 열림 테두리(시트는 화면에서 연결)',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  // 시트가 열려 있는 동안을 2초로 흉내 냅니다.
                  child: LuckyCardRow(
                    items: _luckyItems,
                    onOpen: (_) =>
                        Future<void>.delayed(const Duration(seconds: 2)),
                  ),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: '표시 전용(onOpen: null)',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: LuckyCardRow(items: _luckyItems),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: '색이 둘인 날: 두 칸 알약(D119, V114)',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: LuckyCardRow(
                    items: _pairLuckyItems,
                    onOpen: (_) =>
                        Future<void>.delayed(const Duration(seconds: 2)),
                  ),
                ),
              ),
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'ColorPairSheetBody',
          useCases: [
            WidgetbookUseCase(
              name: '색이 둘인 날 행운 색 시트',
              builder: (context) =>
                  Stage(child: SizedBox(width: 360, child: _colorPairSheet())),
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'TimeBand',
          useCases: [
            WidgetbookUseCase(
              name: '07:30부터: 낮이 앞',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 312,
                  child: _timeBand(beforeDayStart: false),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: '07:30 전: 밤이 앞',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 312,
                  child: _timeBand(beforeDayStart: true),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    WidgetbookFolder(
      name: 'share-image',
      children: [
        for (final variant in ShareImageVariant.values)
          WidgetbookComponent(
            name: variant.name,
            useCases: [
              WidgetbookUseCase(
                name: '논리 크기 그대로(라이트 고정)',
                builder: (context) => Stage(child: _shareImage(variant)),
              ),
            ],
          ),
        WidgetbookComponent(
          name: 'ShareImagePreview',
          useCases: [
            WidgetbookUseCase(
              name: '비율을 바꾸면 appear.seep',
              builder: (context) =>
                  const Stage(child: SizedBox(width: 240, child: _RatioDemo())),
            ),
          ],
        ),
      ],
    ),
    WidgetbookFolder(
      name: 'guide-question-card',
      children: [
        WidgetbookComponent(
          name: 'GuideQuestionCard',
          useCases: [
            WidgetbookUseCase(
              name: 'before',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: _guideCard(GuideQuestionState.before),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'after',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: _guideCard(GuideQuestionState.after),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'full(그날 일기 다 채움)',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: _guideCard(GuideQuestionState.full),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: '누르면 상태가 바뀜(도장 찍힘)',
              builder: (context) => const Stage(
                child: SizedBox(width: 360, child: _GuideToggleDemo()),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// 버튼을 누를 때마다 before와 after를 오가며 도장이 찍히는 모습을 보여 줍니다.
class _GuideToggleDemo extends StatefulWidget {
  const new();

  @override
  State<_GuideToggleDemo> createState() => _GuideToggleDemoState();
}

class _GuideToggleDemoState extends State<_GuideToggleDemo> {
  GuideQuestionState _state = GuideQuestionState.before;

  @override
  Widget build(BuildContext context) => _guideCard(
    _state,
    onAction: () => setState(
      () => _state = _state == GuideQuestionState.before
          ? GuideQuestionState.after
          : GuideQuestionState.before,
    ),
  );
}

/// 누를 때마다 story, feed, square를 돌며 비율 전환(`ratioChanged`)을 보여 줍니다.
class _RatioDemo extends StatefulWidget {
  const new();

  @override
  State<_RatioDemo> createState() => _RatioDemoState();
}

class _RatioDemoState extends State<_RatioDemo> {
  ShareImageVariant _variant = ShareImageVariant.story;

  void _next() => setState(() {
    const all = ShareImageVariant.values;
    _variant = all[(_variant.index + 1) % all.length];
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      ShareImagePreview(image: _shareImage(_variant)),
      TextButton(onPressed: _next, child: Text('비율 바꾸기 (${_variant.name})')),
    ],
  );
}
