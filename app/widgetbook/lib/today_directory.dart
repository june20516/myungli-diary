import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

final RenderedText _reason = RenderedText(
  segments: [Segment(text: '오늘은 기운의 흐름이 나를 도와주는 날이에요.')],
);

final List<LuckyItem> _luckyItems = [
  LuckyItem(
    variant: LuckyCardVariant.color,
    name: '행운 색',
    value: '파랑',
    explain: RenderedText(segments: [Segment(text: '물의 기운이 마음을 가라앉혀 줘요.')]),
    swatch: const Color(0xFF3B6FB6),
  ),
  LuckyItem(
    variant: LuckyCardVariant.direction,
    name: '행운 방향',
    value: '동쪽',
    explain: RenderedText(segments: [Segment(text: '동쪽에서 좋은 기운이 들어와요.')]),
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
    value: '오후 3시',
    explain: RenderedText(segments: [Segment(text: '오후 3시쯤 집중이 잘 돼요.')]),
  ),
];

String _name(DayKind kind) => switch (kind) {
  DayKind.yongsinDay => '좋은 날',
  DayKind.gwiinDay => '귀인의 날',
  DayKind.gisinDay => '기신의 날',
  DayKind.ordinaryDay => '평범한 날',
};

/// 오늘 카탈로그: day-character(good·gwiin·gisin·ordinary), lucky-card(네 변형 칩 줄).
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
  ],
);
