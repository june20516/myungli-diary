import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
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
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';

import '../support/golden.dart';

bool _ja(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja';

TermToken _label(String text) =>
    TermToken(label: text, variant: TermTokenVariant.label, onTap: () {});

LuckLabel _luck(String text) => LuckLabel(text, onTap: () {});

OhaengCell _cell(FiveElement element, String hanja, String reading) =>
    OhaengCell(element: element, hanja: hanja, reading: reading);

/// member 원국(癸未·庚辰·辛巳·庚午). [hourUnknown]이면 시주가 빈 칸입니다.
Widget _member(BuildContext context, {bool hourUnknown = false}) {
  final ja = _ja(context);
  SajuPillarColumn column(
    String header,
    OhaengCell stem,
    OhaengCell branch,
    String top,
    String bottom,
  ) => SajuPillarColumn(
    header: header,
    semanticLabel: header,
    stem: stem,
    branch: branch,
    stemLabel: _label(top),
    branchLabel: _label(bottom),
  );
  return SajuPillars(
    hour: hourUnknown
        ? SajuPillarColumn(header: ja ? '時柱' : '시주', semanticLabel: '')
        : column(
            ja ? '時柱' : '시주',
            _cell(FiveElement.water, '癸', ja ? 'き' : '계'),
            _cell(FiveElement.earth, '未', ja ? 'び' : '미'),
            ja ? '傷官' : '상관',
            ja ? '正印' : '정인',
          ),
    day: column(
      ja ? '日柱' : '일주',
      _cell(FiveElement.metal, '庚', ja ? 'こう' : '경'),
      _cell(FiveElement.earth, '辰', ja ? 'しん' : '진'),
      ja ? '日干' : '일간',
      ja ? '偏印' : '편인',
    ),
    month: column(
      ja ? '月柱' : '월주',
      _cell(FiveElement.metal, '辛', ja ? 'しん' : '신'),
      _cell(FiveElement.fire, '巳', ja ? 'し' : '사'),
      ja ? '劫財' : '겁재',
      ja ? '偏官' : '편관',
    ),
    year: column(
      ja ? '年柱' : '연주',
      _cell(FiveElement.metal, '庚', ja ? 'こう' : '경'),
      _cell(FiveElement.fire, '午', ja ? 'ご' : '오'),
      ja ? '比肩' : '비견',
      ja ? '正官' : '정관',
    ),
    meLabel: ja ? '私' : '나',
    tableLabel: ja ? '命式' : '원국표',
  );
}

OhaengBar _ohaengBar(BuildContext context, Map<FiveElement, double> values) {
  final ja = Localizations.localeOf(context).languageCode == 'ja';
  const ko = {
    FiveElement.wood: '목',
    FiveElement.fire: '화',
    FiveElement.earth: '토',
    FiveElement.metal: '금',
    FiveElement.water: '수',
  };
  const jaNames = {
    FiveElement.wood: '木',
    FiveElement.fire: '火',
    FiveElement.earth: '土',
    FiveElement.metal: '金',
    FiveElement.water: '水',
  };
  return OhaengBar(
    semanticLabel: '',
    items: [
      for (final element in FiveElement.values)
        OhaengBarItem(
          element: element,
          name: (ja ? jaNames : ko)[element]!,
          value: values[element] ?? 0,
          count: (values[element] ?? 0).toStringAsFixed(1),
        ),
    ],
  );
}

/// member 만세력. [hourUnknown]이면 시주 열이 빕니다.
Widget _manse(BuildContext context, {bool hourUnknown = false}) {
  final ja = _ja(context);
  BandHiddenStem h(
    FiveElement element,
    String hanja,
    String reading, [
    String? god,
  ]) => BandHiddenStem(
    element: element,
    hanja: hanja,
    semanticLabel: '$hanja $reading',
    tenGod: god == null ? null : LuckLabel(god, onTap: () {}),
  );
  LuckLabel value(String text) => LuckLabel(text, onTap: () {});
  return ManseTable(
    basis: ja ? '自分の日干庚が基準' : '내 일간 庚(경금) 기준',
    basisGlyph: '庚',
    table: BandTable(
      columns: [
        if (hourUnknown)
          BandColumn(header: ja ? '時柱' : '시주', empty: true)
        else
          BandColumn(
            header: ja ? '時柱' : '시주',
            hiddenStems: [
              h(FiveElement.fire, '丁', '정', ja ? '正官' : '정관'),
              h(FiveElement.wood, '乙', '을', ja ? '正財' : '정재'),
              h(FiveElement.earth, '己', '기', ja ? '正印' : '정인'),
            ],
            twelveStage: value(ja ? '冠帯' : '관대'),
            shinsal: [value(ja ? '天乙貴人' : '천을귀인')],
          ),
        BandColumn(
          header: ja ? '日柱' : '일주',
          isDay: true,
          hiddenStems: [
            h(FiveElement.wood, '乙', '을', ja ? '正財' : '정재'),
            h(FiveElement.water, '癸', '계', ja ? '傷官' : '상관'),
            h(FiveElement.earth, '戊', '무', ja ? '偏印' : '편인'),
          ],
          twelveStage: value(ja ? '養' : '양'),
          shinsal: [value(ja ? '華蓋' : '화개')],
        ),
        BandColumn(
          header: ja ? '月柱' : '월주',
          hiddenStems: [
            h(FiveElement.fire, '丙', '병', ja ? '偏官' : '편관'),
            h(FiveElement.metal, '庚', '경', ja ? '比肩' : '비견'),
            h(FiveElement.earth, '戊', '무', ja ? '偏印' : '편인'),
          ],
          twelveStage: value(ja ? '長生' : '장생'),
        ),
        BandColumn(
          header: ja ? '年柱' : '연주',
          hiddenStems: [
            h(FiveElement.fire, '丁', '정', ja ? '正官' : '정관'),
            h(FiveElement.earth, '己', '기', ja ? '正印' : '정인'),
          ],
          // 사전에 이름이 없으면(A65) 화면은 누를 수 없는 글자를 넘깁니다.
          twelveStage: LuckLabel(ja ? '沐浴' : '목욕'),
        ),
      ],
      bandLabels: {
        BandKind.hiddenStems: ja ? '蔵干' : '지장간',
        BandKind.twelveStages: ja ? '十二運' : '12운성',
        BandKind.shinsal: ja ? '神殺' : '신살',
      },
      onBandTap: (_) {},
      meLabel: ja ? 'わたし' : '나',
      emptyLabel: ja ? 'なし' : '없음',
      tableLabel: ja ? '万年暦' : '만세력 표',
    ),
  );
}

const List<(int, Stem, Branch)> _memberDaeun = [
  (4, Stem.gyeong, Branch.jin),
  (14, Stem.gi, Branch.myo),
  (24, Stem.mu, Branch.in_),
  (34, Stem.jeong, Branch.chuk),
  (44, Stem.byeong, Branch.ja),
  (54, Stem.eul, Branch.hae),
  (64, Stem.gap, Branch.sul),
  (74, Stem.gye, Branch.yu),
  (84, Stem.im, Branch.shin),
  (94, Stem.sin, Branch.mi),
];

const List<(int, Stem, Branch)> _memberSeun = [
  (2023, Stem.gye, Branch.myo),
  (2024, Stem.gap, Branch.jin),
  (2025, Stem.eul, Branch.sa),
  (2026, Stem.byeong, Branch.o),
  (2027, Stem.jeong, Branch.mi),
  (2028, Stem.mu, Branch.shin),
  (2029, Stem.gi, Branch.yu),
  (2030, Stem.gyeong, Branch.sul),
  (2031, Stem.sin, Branch.hae),
  (2032, Stem.im, Branch.ja),
];

/// member 대운(지금 34세)·세운(올해 2026).
Widget _daeun(BuildContext context) {
  final ja = _ja(context);
  final l10n = AppLocalizations.of(context);
  LuckGanji ganji(Stem s, Branch b) => LuckGanji(
    stemElement: stemElement(s),
    stemHanja: stemHanja(s),
    branchElement: branchElement(b),
    branchHanja: branchHanja(b),
  );
  return DaeunTable(
    daeun: [
      for (final (age, s, b) in _memberDaeun)
        DaeunPillar(
          age: age,
          startYear: 1989 + age,
          pillar: ganji(s, b),
          ageSemanticLabel: '$age',
          semanticLabel: '$age',
          yearSemanticLabel: '${1989 + age}',
          stemLabel: _luck(ja ? '比肩' : '비견'),
          branchLabel: _luck(ja ? '偏印' : '편인'),
          stageLabel: _luck(ja ? '長生' : '장생'),
        ),
    ],
    seun: [
      for (final (year, s, b) in _memberSeun)
        SeunYear(
          year: year,
          pillar: ganji(s, b),
          yearSemanticLabel: '$year',
          semanticLabel: '$year',
          label: _luck(ja ? '傷官' : '상관'),
        ),
    ],
    currentIndex: 3,
    thisYear: 2026,
    nowLabel: ja ? '今' : '지금',
    thisYearLabel: ja ? '今年' : '올해',
    daeunTitle: l10n.sajuChartDaeunTitle,
    daeunDescription: l10n.sajuChartDaeunDesc,
    seunTitle: l10n.sajuChartSeunTitle,
    seunDescription: l10n.sajuChartSeunDesc,
  );
}

void main() {
  goldenTest('saju-pillars: 원국표·시간 모름·loading', (tester) async {
    await goldenMatrix(
      tester,
      'saju_pillars',
      () => Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s24,
          children: [
            _member(context),
            _member(context, hourUnknown: true),
            const SkeletonBlock(
              delay: Duration.zero,
              child: SajuPillarsSkeleton(animated: false),
            ),
          ],
        ),
      ),
    );
  });

  goldenTest('ohaeng-bar: member 분포·0이 섞인 분포', (tester) async {
    await goldenMatrix(
      tester,
      'saju_ohaeng_bar',
      () => Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s24,
          children: [
            _ohaengBar(context, const {
              FiveElement.wood: 0.6,
              FiveElement.fire: 3.3,
              FiveElement.earth: 2.55,
              FiveElement.metal: 2.9,
              FiveElement.water: 1.15,
            }),
            _ohaengBar(context, const {
              FiveElement.fire: 4,
              FiveElement.metal: 2,
            }),
          ],
        ),
      ),
    );
  });

  goldenTest('manse-table: member 만세력·시간 모름', (tester) async {
    await goldenMatrix(
      tester,
      'saju_manse_table',
      () => Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s24,
          children: [_manse(context), _manse(context, hourUnknown: true)],
        ),
      ),
    );
  });

  goldenTest('daeun-table: 대운(지금)·세운(올해)', (tester) async {
    await goldenMatrix(
      tester,
      'saju_daeun_table',
      () => const Builder(builder: _daeun),
    );
  });
}
