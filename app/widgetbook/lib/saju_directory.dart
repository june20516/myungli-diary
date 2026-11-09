import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

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

/// 지장간 하나: 오행 색 칩 + 십성.
BandHiddenStem _hidden(
  FiveElement element,
  String hanja,
  String reading, [
  String? tenGod,
]) => BandHiddenStem(
  element: element,
  hanja: hanja,
  semanticLabel: '$hanja $reading',
  tenGod: tenGod == null ? null : LuckLabel(tenGod, onTap: _noop),
);

/// 만세력 예시. [hourUnknown]이면 시주 열이 빕니다.
Widget _manse({bool hourUnknown = false}) => SizedBox(
  width: 360,
  child: ManseTable(
    basis: '내 일간 庚(경금) 기준',
    basisGlyph: '庚',
    table: BandTable(
      columns: [
        if (hourUnknown)
          const BandColumn(header: '시주', empty: true)
        else
          BandColumn(
            header: '시주',
            hiddenStems: [
              _hidden(FiveElement.fire, '丁', '정', '정관'),
              _hidden(FiveElement.wood, '乙', '을', '정재'),
              _hidden(FiveElement.earth, '己', '기', '정인'),
            ],
            twelveStage: const LuckLabel('관대', onTap: _noop),
            shinsal: const [LuckLabel('천을귀인', onTap: _noop)],
          ),
        BandColumn(
          header: '일주',
          isDay: true,
          hiddenStems: [
            _hidden(FiveElement.wood, '乙', '을', '정재'),
            _hidden(FiveElement.water, '癸', '계', '상관'),
            _hidden(FiveElement.earth, '戊', '무', '편인'),
          ],
          twelveStage: const LuckLabel('양', onTap: _noop),
          shinsal: const [LuckLabel('화개', onTap: _noop)],
        ),
        BandColumn(
          header: '월주',
          hiddenStems: [
            _hidden(FiveElement.fire, '丙', '병', '편관'),
            _hidden(FiveElement.metal, '庚', '경', '비견'),
            _hidden(FiveElement.earth, '戊', '무', '편인'),
          ],
          twelveStage: const LuckLabel('장생', onTap: _noop),
        ),
        BandColumn(
          header: '연주',
          hiddenStems: [
            _hidden(FiveElement.fire, '丁', '정', '정관'),
            _hidden(FiveElement.earth, '己', '기', '정인'),
          ],
          // 사전에 이름이 없으면(A65) 누를 수 없는 글자입니다.
          twelveStage: const LuckLabel('목욕'),
        ),
      ],
      bandLabels: const {
        BandKind.hiddenStems: '지장간',
        BandKind.twelveStages: '12운성',
        BandKind.shinsal: '신살',
      },
      onBandTap: (_) {},
      meLabel: '나',
      emptyLabel: '없음',
      tableLabel: '만세력 표',
    ),
  ),
);

/// 대운, 세운 칸의 간지.
LuckGanji _ganji(
  FiveElement stemElement,
  String stemHanja,
  FiveElement branchElement,
  String branchHanja,
) => LuckGanji(
  stemElement: stemElement,
  stemHanja: stemHanja,
  branchElement: branchElement,
  branchHanja: branchHanja,
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
            pillar: _ganji(se, sh, be, bh),
            ageSemanticLabel: '대운 $age세부터',
            semanticLabel: '$sh $bh',
            yearSemanticLabel: '${1989 + age}년',
            stemLabel: const LuckLabel('비견', onTap: _noop),
            branchLabel: const LuckLabel('편인', onTap: _noop),
            stageLabel: const LuckLabel('장생', onTap: _noop),
          ),
      ],
      seun: [
        for (final (year, se, sh, be, bh) in seun)
          SeunYear(
            year: year,
            pillar: _ganji(se, sh, be, bh),
            yearSemanticLabel: '$year년',
            semanticLabel: '$sh $bh',
            label: const LuckLabel('상관', onTap: _noop),
          ),
      ],
      currentIndex: 3,
      thisYear: 2026,
      nowLabel: '지금',
      thisYearLabel: '올해',
      daeunTitle: '대운',
      daeunDescription: '10년마다 바뀌는 큰 흐름이에요.',
      seunTitle: '세운',
      seunDescription: '해마다 들어오는 기운이에요.',
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
