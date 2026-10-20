import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
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

OhaengCell _mini(FiveElement element, String hanja) =>
    OhaengCell(element: element, hanja: hanja, size: OhaengCellSize.mini);

/// 만세력 예시. [hourUnknown]이면 시주 열이 빕니다.
Widget _manse({bool hourUnknown = false}) => SizedBox(
  width: 360,
  child: ManseTable(
    hour: hourUnknown
        ? const ManseColumn(header: '시주')
        : ManseColumn(
            header: '시주',
            stem: _mini(FiveElement.water, '癸'),
            branch: _mini(FiveElement.earth, '未'),
            hiddenStems: const [
              ManseHiddenStem(hanja: '丁', reading: '정'),
              ManseHiddenStem(hanja: '乙', reading: '을'),
              ManseHiddenStem(hanja: '己', reading: '기'),
            ],
            twelveStage: '관대',
            shinsal: const ['천을귀인'],
          ),
    day: ManseColumn(
      header: '일주',
      stem: _mini(FiveElement.metal, '庚'),
      branch: _mini(FiveElement.earth, '辰'),
      hiddenStems: const [
        ManseHiddenStem(hanja: '乙', reading: '을'),
        ManseHiddenStem(hanja: '癸', reading: '계'),
        ManseHiddenStem(hanja: '戊', reading: '무'),
      ],
      twelveStage: '양',
      shinsal: const ['화개'],
    ),
    month: ManseColumn(
      header: '월주',
      stem: _mini(FiveElement.metal, '辛'),
      branch: _mini(FiveElement.fire, '巳'),
      hiddenStems: const [
        ManseHiddenStem(hanja: '丙', reading: '병'),
        ManseHiddenStem(hanja: '庚', reading: '경'),
        ManseHiddenStem(hanja: '戊', reading: '무'),
      ],
      twelveStage: '장생',
    ),
    year: ManseColumn(
      header: '연주',
      stem: _mini(FiveElement.metal, '庚'),
      branch: _mini(FiveElement.fire, '午'),
      hiddenStems: const [
        ManseHiddenStem(hanja: '丁', reading: '정'),
        ManseHiddenStem(hanja: '己', reading: '기'),
      ],
      twelveStage: '목욕',
    ),
    hiddenStemsHeader: _label('지장간'),
    twelveStageHeader: _label('12운성'),
    shinsalHeader: _label('신살'),
    tableLabel: '만세력 표',
  ),
);

/// 대운 예시(지금 34세)와 세운(올해 2026). 칸 글자는 예시용 고정 값입니다.
Widget _daeun() {
  const daeun = [
    (4, FiveElement.metal, '庚', FiveElement.earth, '辰'),
    (14, FiveElement.earth, '己', FiveElement.wood, '卯'),
    (24, FiveElement.earth, '戊', FiveElement.wood, '寅'),
    (34, FiveElement.fire, '丁', FiveElement.earth, '丑'),
    (44, FiveElement.fire, '丙', FiveElement.water, '子'),
    (54, FiveElement.wood, '乙', FiveElement.water, '亥'),
  ];
  const seun = [
    (2023, FiveElement.water, '癸', FiveElement.wood, '卯'),
    (2024, FiveElement.wood, '甲', FiveElement.earth, '辰'),
    (2025, FiveElement.wood, '乙', FiveElement.fire, '巳'),
    (2026, FiveElement.fire, '丙', FiveElement.fire, '午'),
    (2027, FiveElement.fire, '丁', FiveElement.earth, '未'),
    (2028, FiveElement.earth, '戊', FiveElement.metal, '申'),
    (2029, FiveElement.earth, '己', FiveElement.metal, '酉'),
    (2030, FiveElement.metal, '庚', FiveElement.earth, '戌'),
    (2031, FiveElement.metal, '辛', FiveElement.water, '亥'),
    (2032, FiveElement.water, '壬', FiveElement.water, '子'),
  ];
  return SizedBox(
    width: 360,
    child: DaeunTable(
      daeun: [
        for (final (age, se, sh, be, bh) in daeun)
          DaeunPillar(
            age: age,
            startYear: 1989 + age,
            stem: _mini(se, sh),
            branch: _mini(be, bh),
            semanticLabel: '$age세',
          ),
      ],
      seun: [
        for (final (year, se, sh, be, bh) in seun)
          SeunYear(
            year: year,
            stem: _mini(se, sh),
            branch: _mini(be, bh),
            semanticLabel: '$year년',
          ),
      ],
      currentIndex: 3,
      thisYear: 2026,
      nowLabel: '지금',
      thisYearLabel: '올해',
      tableLabel: '대운 4세부터',
    ),
  );
}

/// 사주 카탈로그: daeun-table(대운·세운), saju-pillars(원국표·시간 모름·loading),
/// ohaeng-bar(분포·zero), manse-table(만세력·시간 모름).
final WidgetbookFolder sajuDirectory = WidgetbookFolder(
  name: '사주',
  children: [
    WidgetbookComponent(
      name: 'daeun-table',
      useCases: [
        WidgetbookUseCase(
          name: '대운·세운',
          builder: (context) => Stage(child: _daeun()),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'manse-table',
      useCases: [
        WidgetbookUseCase(
          name: '만세력',
          builder: (context) => Stage(child: _manse()),
        ),
        WidgetbookUseCase(
          name: 'time-unknown',
          builder: (context) => Stage(child: _manse(hourUnknown: true)),
        ),
      ],
    ),
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
