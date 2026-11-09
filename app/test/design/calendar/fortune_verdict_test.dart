import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/score_item.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/fortune_verdict.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../../support/fonts.dart';
import '../input/input_harness.dart';

const _names = {
  'yongsin_day': '용신의 날',
  'gwiin_day': '귀인의 날',
  'hap': '합',
  'gisin_day': '기신의 날',
  'chung_other': '다른 자리와의 충',
};

Widget _app(Widget child, {bool disableAnimations = false}) => inputApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  ),
);

FortuneVerdict _verdict({
  int score = 0,
  List<ScoreItem>? items,
  void Function(ScoreItem)? onItemTap,
  void Function(List<String>)? onUnrenderable,
}) => FortuneVerdict(
  score: score,
  items: items,
  nameOf: (id) => _names[id],
  meaningOf: (id) => '${_names[id]} 뜻',
  onItemTap: onItemTap,
  onUnrenderable: onUnrenderable,
);

ScoreItem _item(String id, int score) => ScoreItem(id: id, score: score);

/// 표시 원의 가로 위치(막대 안쪽 폭 기준 0~1).
double _markerPosition(WidgetTester tester) {
  final track = tester.getRect(find.byKey(FortuneVerdict.trackKey));
  final marker = tester.getRect(find.byKey(FortuneVerdict.markerKey));
  return (marker.center.dx - track.left) / track.width;
}

void main() {
  setUpAll(loadBundledFonts);

  group('위치 계산', () {
    test('자르고 (score+3)/6', () {
      expect(FortuneVerdict.positionOf(-5), 0);
      expect(FortuneVerdict.positionOf(-3), 0);
      expect(FortuneVerdict.positionOf(0), 0.5);
      expect(FortuneVerdict.positionOf(3), 1);
      expect(FortuneVerdict.positionOf(7), 1);
      expect(FortuneVerdict.positionOf(1), closeTo(4 / 6, 1e-9));
    });

    testWidgets('표시 원이 막대 위 계산한 자리에 있음', (tester) async {
      for (final (score, expected) in [(-5, 0.0), (0, 0.5), (3, 1.0)]) {
        await tester.pumpWidget(_app(_verdict(score: score)));
        expect(_markerPosition(tester), closeTo(expected, 1e-6));
      }
    });
  });

  group('내역 정렬', () {
    test('더함 먼저 뺌 다음, 같은 부호는 server 순서', () {
      final ordered = FortuneVerdict.orderedItems([
        _item('a', -1),
        _item('b', 2),
        _item('c', -2),
        _item('d', 1),
      ]);
      expect([for (final i in ordered) i.score], [2, 1, -1, -2]);
      expect([for (final i in ordered) i.id], ['b', 'd', 'a', 'c']);
    });

    test('점수 0은 제외', () {
      final ordered = FortuneVerdict.orderedItems([
        _item('a', 0),
        _item('b', 1),
      ]);
      expect([for (final i in ordered) i.id], ['b']);
    });

    testWidgets('화면에 정렬한 순서로 줄, 줄마다 위에 구분선', (tester) async {
      await tester.pumpWidget(
        _app(
          _verdict(
            items: [
              _item('gisin_day', -1),
              _item('yongsin_day', 2),
              _item('chung_other', -1),
              _item('hap', 1),
              _item('gwiin_day', 0),
            ],
          ),
        ),
      );
      final rows = tester.widgetList<ScoreRow>(find.byType(ScoreRow)).toList();
      expect(
        [for (final r in rows) r.name],
        ['용신의 날', '합', '기신의 날', '다른 자리와의 충'],
      );
      expect(find.byType(ListDivider), findsNWidgets(4));
    });
  });

  group('noBreakdown, noItems', () {
    for (final (label, items) in [
      ('items null', null as List<ScoreItem>?),
      ('items 빈 배열', <ScoreItem>[]),
    ]) {
      testWidgets('$label: 막대와 세 이름만', (tester) async {
        await tester.pumpWidget(_app(_verdict(items: items)));
        final l10n = AppLocalizations.of(
          tester.element(find.byType(FortuneVerdict)),
        );
        expect(find.byType(ScoreRow), findsNothing);
        expect(find.byKey(FortuneVerdict.markerKey), findsOneWidget);
        expect(find.text(l10n.calendarLegendBodyCaution), findsOneWidget);
        expect(find.text(l10n.calendarLegendBodyNeutral), findsOneWidget);
        expect(find.text(l10n.calendarLegendBodyGood), findsOneWidget);
      });
    }
  });

  testWidgets('이름이 없는 항목은 줄을 그리지 않고 id를 알림', (tester) async {
    List<String>? reported;
    await tester.pumpWidget(
      _app(
        _verdict(
          items: [_item('hyeong', -1), _item('hap', 1)],
          onUnrenderable: (ids) => reported = ids,
        ),
      ),
    );
    await tester.pump();
    expect(tester.widgetList<ScoreRow>(find.byType(ScoreRow)).length, 1);
    expect(reported, ['hyeong']);
  });

  testWidgets('태그를 누르면 onItemTap에 그 항목', (tester) async {
    ScoreItem? tapped;
    await tester.pumpWidget(
      _app(
        _verdict(items: [_item('hap', 1)], onItemTap: (item) => tapped = item),
      ),
    );
    await tester.tap(find.text('합').first);
    expect(tapped?.id, 'hap');
  });

  testWidgets('카드 bg.base, 막대 높이 4, 표시 원 18', (tester) async {
    await tester.pumpWidget(_app(_verdict()));
    final tokens = tester.element(find.byType(FortuneVerdict)).tokens;
    final card = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(FortuneVerdict),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((card.decoration as BoxDecoration).color, tokens.colors.bgBase);
    expect(tester.getSize(find.byKey(FortuneVerdict.trackKey)).height, 4);
    expect(
      tester.getSize(find.byKey(FortuneVerdict.markerKey)),
      const Size(18, 18),
    );
    final marker =
        tester
                .widget<DecoratedBox>(find.byKey(FortuneVerdict.markerKey))
                .decoration
            as BoxDecoration;
    expect(marker.color, tokens.colors.bgSheet);
    expect(marker.border!.top.color, tokens.colors.actionPrimary);
    expect(marker.border!.top.width, 2);
    final track =
        tester
                .widget<DecoratedBox>(find.byKey(FortuneVerdict.trackKey))
                .decoration
            as BoxDecoration;
    expect(track.gradient, tokens.gradients.verdictTrack);
  });

  testWidgets('동작 줄이기와 상관없이 표시 원은 같은 자리, 애니메이션 없음', (tester) async {
    await tester.pumpWidget(_app(_verdict(score: 2)));
    final normal = tester.getTopLeft(find.byKey(FortuneVerdict.markerKey));
    await tester.pumpWidget(_app(_verdict(score: 2), disableAnimations: true));
    expect(tester.getTopLeft(find.byKey(FortuneVerdict.markerKey)), normal);
    // 처음 그린 프레임부터 제자리: 시간이 흘러도 움직이지 않음.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.byKey(FortuneVerdict.markerKey)), normal);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('스크린리더: 섹션 제목, 단계 이름 한 묶음', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_verdict()));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(FortuneVerdict)),
    );
    expect(
      find.bySemanticsLabel(
        '${l10n.daySheetVerdictTitle}, ${l10n.calendarLegendBodyNeutral}',
      ),
      findsOneWidget,
    );
    expect(
      FortuneVerdict.levelNameOf(l10n, -2),
      l10n.calendarLegendBodyCaution,
    );
    expect(FortuneVerdict.levelNameOf(l10n, 1), l10n.calendarLegendBodyNeutral);
    expect(FortuneVerdict.levelNameOf(l10n, 2), l10n.calendarLegendBodyGood);
    handle.dispose();
  });

  testWidgets('로딩 뼈: 막대 자리와 score-row 뼈 두 줄', (tester) async {
    await tester.pumpWidget(_app(FortuneVerdict.skeleton(animated: false)));
    expect(tester.takeException(), isNull);
    expect(find.byType(FortuneVerdict), findsNothing);
  });

  testWidgets('내역이 있어도 섹션 묶음이 줄 의미를 삼키지 않음', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(_verdict(items: [_item('hap', 1), _item('gisin_day', -2)])),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(FortuneVerdict)),
    );
    expect(
      find.bySemanticsLabel('합, 합 뜻, ${l10n.daySheetVerdictItemPlus(1)}'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '기신의 날, 기신의 날 뜻, ${l10n.daySheetVerdictItemMinus(2)}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '${l10n.daySheetVerdictTitle}, ${l10n.calendarLegendBodyNeutral}',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
