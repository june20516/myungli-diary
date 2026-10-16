import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

final RenderedText _guideQuestion = RenderedText(
  segments: [Segment(text: '오늘 가장 오래 마음에 남은 장면은 무엇인가요?')],
);

Widget _guideCard(GuideQuestionState state, {VoidCallback? onAction}) =>
    GuideQuestionCard(
      state: state,
      eyebrow: '오늘의 질문',
      question: _guideQuestion,
      actionLabel: state == GuideQuestionState.before ? '일기 쓰기' : '쓴 일기 보기',
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
  LuckyItem(
    variant: LuckyCardVariant.time,
    name: '집중하기 좋은 시간',
    value: '09:30–11:30 · 13:30–15:30',
    explain: RenderedText(segments: [Segment(text: '오후 3시쯤 집중이 잘 돼요.')]),
  ),
];

/// 대표 태그(D76). 두 번째는 뜻이 없어 누를 수 없는 이름 칩입니다.
final List<LuckyTag> _luckyTags = [
  LuckyTag(
    tagKey: 'cheoneul_gwiin',
    name: '천을귀인',
    meaning: RenderedText(
      segments: [Segment(text: '어려울 때 도와주는 사람이 곁에 오는 기운이에요.')],
    ),
  ),
  const LuckyTag(tagKey: 'clash', name: '충'),
];

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
/// share-image(story·feed·square와 비율 전환 미리보기).
final WidgetbookFolder todayDirectory = WidgetbookFolder(
  name: '오늘',
  children: [
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
              name: '누르면 설명이 열림',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: LuckyCardRow(items: _luckyItems),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: '대표 태그 칩 포함(D76)',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: LuckyCardRow(items: _luckyItems, tags: _luckyTags),
                ),
              ),
            ),
            WidgetbookUseCase(
              name: '공유 이미지(interactive: false)',
              builder: (context) => Stage(
                child: SizedBox(
                  width: 360,
                  child: LuckyCardRow(items: _luckyItems, interactive: false),
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
