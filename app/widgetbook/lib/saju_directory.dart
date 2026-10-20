import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

TermToken _label(String text) =>
    TermToken(label: text, variant: TermTokenVariant.label, onTap: () {});

SajuPillarColumn _column(
  String header,
  (FiveElement, String, String) stem,
  (FiveElement, String, String) branch,
  String top,
  String bottom,
) => SajuPillarColumn(
  header: header,
  semanticLabel: header,
  stem: OhaengCell(element: stem.$1, hanja: stem.$2, reading: stem.$3),
  branch: OhaengCell(element: branch.$1, hanja: branch.$2, reading: branch.$3),
  stemLabel: _label(top),
  branchLabel: _label(bottom),
);

/// 원국표 예시(癸未·庚辰·辛巳·庚午). [hourUnknown]이면 시주가 빈 칸입니다.
Widget _pillars({bool hourUnknown = false}) => SizedBox(
  width: 360,
  child: SajuPillars(
    hour: hourUnknown
        ? const SajuPillarColumn(header: '시주', semanticLabel: '시주')
        : _column(
            '시주',
            (FiveElement.water, '癸', '계'),
            (FiveElement.earth, '未', '미'),
            '상관',
            '정인',
          ),
    day: _column(
      '일주',
      (FiveElement.metal, '庚', '경'),
      (FiveElement.earth, '辰', '진'),
      '일간',
      '편인',
    ),
    month: _column(
      '월주',
      (FiveElement.metal, '辛', '신'),
      (FiveElement.fire, '巳', '사'),
      '겁재',
      '편관',
    ),
    year: _column(
      '연주',
      (FiveElement.metal, '庚', '경'),
      (FiveElement.fire, '午', '오'),
      '비견',
      '정관',
    ),
    meLabel: '나',
    tableLabel: '원국표',
  ),
);

Widget _ohaengBar(Map<FiveElement, double> values) => SizedBox(
  width: 360,
  child: OhaengBar(
    semanticLabel: '오행 분포',
    items: [
      for (final (element, name) in [
        (FiveElement.wood, '목'),
        (FiveElement.fire, '화'),
        (FiveElement.earth, '토'),
        (FiveElement.metal, '금'),
        (FiveElement.water, '수'),
      ])
        OhaengBarItem(
          element: element,
          name: name,
          value: values[element] ?? 0,
          count: (values[element] ?? 0).toStringAsFixed(1),
        ),
    ],
  ),
);

/// 사주 카탈로그: saju-pillars(원국표·시간 모름·loading), ohaeng-bar(분포·zero).
final WidgetbookFolder sajuDirectory = WidgetbookFolder(
  name: '사주',
  children: [
    WidgetbookComponent(
      name: 'ohaeng-bar',
      useCases: [
        WidgetbookUseCase(
          name: '분포',
          builder: (context) => Stage(
            child: _ohaengBar(const {
              FiveElement.wood: 0.6,
              FiveElement.fire: 3.3,
              FiveElement.earth: 2.55,
              FiveElement.metal: 2.9,
              FiveElement.water: 1.15,
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'zero',
          builder: (context) => Stage(
            child: _ohaengBar(const {
              FiveElement.fire: 4,
              FiveElement.metal: 2,
            }),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'saju-pillars',
      useCases: [
        WidgetbookUseCase(
          name: '원국표',
          builder: (context) => Stage(child: _pillars()),
        ),
        WidgetbookUseCase(
          name: 'time-unknown',
          builder: (context) => Stage(child: _pillars(hourUnknown: true)),
        ),
        WidgetbookUseCase(
          name: 'loading',
          builder: (context) => const Stage(
            child: SizedBox(
              width: 360,
              child: SkeletonBlock(child: SajuPillarsSkeleton()),
            ),
          ),
        ),
      ],
    ),
  ],
);
