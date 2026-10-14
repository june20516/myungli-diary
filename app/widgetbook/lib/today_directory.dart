import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

final RenderedText _reason = RenderedText(
  segments: [Segment(text: '오늘은 기운의 흐름이 나를 도와주는 날이에요.')],
);

String _name(DayKind kind) => switch (kind) {
  DayKind.yongsinDay => '좋은 날',
  DayKind.gwiinDay => '귀인의 날',
  DayKind.gisinDay => '기신의 날',
  DayKind.ordinaryDay => '평범한 날',
};

/// 오늘 카탈로그: day-character(good·gwiin·gisin·ordinary).
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
  ],
);
