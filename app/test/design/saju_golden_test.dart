import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

bool _ja(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja';

TermToken _label(String text) =>
    TermToken(label: text, variant: TermTokenVariant.label, onTap: () {});

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
              animated: false,
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
}
