import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/score_item.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/fortune_verdict.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

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

/// 카드의 막대 자리를 눌러 접힘과 펼침을 바꾸고 움직임이 끝날 때까지 기다립니다.
Future<void> _toggle(WidgetTester tester) async {
  await tester.tapAt(_cardCorner(tester));
  await tester.pumpAndSettle();
}

/// 카드 왼쪽 위 안쪽 한 점(막대, 이름, 내역과 겹치지 않는 카드 바탕).
Offset _cardCorner(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(FortuneVerdict.cardKey)) + const Offset(4, 4);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(FortuneVerdict)));

final List<ScoreItem> _twoItems = [_item('hap', 1), _item('gisin_day', -2)];

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
      await _toggle(tester);
      final rows = tester.widgetList<ScoreRow>(find.byType(ScoreRow)).toList();
      expect(
        [for (final r in rows) r.name],
        ['용신의 날', '합', '기신의 날', '다른 자리와의 충'],
      );
      // 내역 줄마다 위에 하나, 그리고 안내 줄 위에 하나.
      expect(
        find.descendant(
          of: find.byType(Column),
          matching: find.byType(ListDivider),
        ),
        findsNWidgets(5),
      );
      Rect rectOf(Element element) {
        final box = element.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }

      final dividerBottoms = [
        for (final d in find.byType(ListDivider).evaluate()) rectOf(d).bottom,
      ];
      for (final row in find.byType(ScoreRow).evaluate()) {
        expect(dividerBottoms, contains(rectOf(row).top));
      }
    });
  });

  group('noBreakdown, noItems', () {
    for (final (label, items) in [
      ('items null', null as List<ScoreItem>?),
      ('items 빈 배열', <ScoreItem>[]),
    ]) {
      testWidgets('$label: 막대와 세 이름만, 안내 줄 없고 누를 수 없음', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(_verdict(items: items)));
        final l10n = _l10n(tester);
        expect(find.byType(ScoreRow), findsNothing);
        expect(find.byKey(FortuneVerdict.markerKey), findsOneWidget);
        expect(find.text(l10n.calendarLegendBodyCaution), findsOneWidget);
        expect(find.text(l10n.calendarLegendBodyNeutral), findsOneWidget);
        expect(find.text(l10n.calendarLegendBodyGood), findsOneWidget);
        expect(find.byKey(FortuneVerdict.toggleKey), findsNothing);
        expect(find.text(l10n.daySheetVerdictExpand), findsNothing);
        expect(inkLayer(find.byType(FortuneVerdict)), findsNothing);
        expect(
          find.bySemanticsIdentifier(SlotIds.daySheetVerdictExpand),
          findsNothing,
        );
        await tester.tapAt(_cardCorner(tester));
        await tester.pumpAndSettle();
        expect(find.byType(ScoreRow), findsNothing);
        // 안내 줄이 없으니 카드 아래 여백 space.16은 그대로입니다.
        final card = tester.getRect(find.byKey(FortuneVerdict.cardKey));
        final names = tester.getRect(find.text(l10n.calendarLegendBodyGood));
        expect(card.bottom - names.bottom, closeTo(Space.s16, 0.01));
        handle.dispose();
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
    // 접힌 채로도 알립니다.
    expect(reported, ['hyeong']);
    await _toggle(tester);
    expect(tester.widgetList<ScoreRow>(find.byType(ScoreRow)).length, 1);
  });

  testWidgets('펼친 내역 태그를 누르면 onItemTap만, 카드는 접히지 않음(V61)', (tester) async {
    ScoreItem? tapped;
    await tester.pumpWidget(
      _app(
        _verdict(items: [_item('hap', 1)], onItemTap: (item) => tapped = item),
      ),
    );
    await _toggle(tester);
    await tester.tap(find.text('합').first);
    await tester.pumpAndSettle();
    expect(tapped?.id, 'hap');
    expect(find.byType(ScoreRow), findsOneWidget);
    expect(find.text(_l10n(tester).daySheetVerdictCollapse), findsOneWidget);
  });

  group('접힘과 펼침 (V108)', () {
    testWidgets('처음에는 접힘: 내역 없이 안내 줄 "내역 보기" + caret-down', (tester) async {
      await tester.pumpWidget(_app(_verdict(items: _twoItems)));
      final l10n = _l10n(tester);
      expect(find.byType(ScoreRow), findsNothing);
      expect(find.text(l10n.daySheetVerdictExpand), findsOneWidget);
      expect(find.text(l10n.daySheetVerdictCollapse), findsNothing);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(FortuneVerdict.toggleKey),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, PhosphorIconsRegular.caretDown);
    });

    testWidgets('카드 아무 곳을 누르면 펼치고, 다시 누르면 접음', (tester) async {
      await tester.pumpWidget(_app(_verdict(items: _twoItems)));
      final l10n = _l10n(tester);
      // 이름 글자(카드 안 아무 곳)를 눌러도 펼칩니다.
      await tester.tap(find.text(l10n.calendarLegendBodyCaution));
      await tester.pumpAndSettle();
      expect(find.byType(ScoreRow), findsNWidgets(2));
      expect(find.text(l10n.daySheetVerdictCollapse), findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(FortuneVerdict.toggleKey),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        PhosphorIconsRegular.caretUp,
      );
      // 안내 줄을 눌러도 같습니다.
      await tester.tap(find.byKey(FortuneVerdict.toggleKey));
      await tester.pumpAndSettle();
      expect(find.byType(ScoreRow), findsNothing);
      expect(find.text(l10n.daySheetVerdictExpand), findsOneWidget);
    });

    testWidgets('다시 만들면(시트를 다시 열면) 늘 접힘', (tester) async {
      await tester.pumpWidget(
        _app(
          KeyedSubtree(
            key: const ValueKey(1),
            child: _verdict(items: _twoItems),
          ),
        ),
      );
      await _toggle(tester);
      expect(find.byType(ScoreRow), findsNWidgets(2));
      await tester.pumpWidget(
        _app(
          KeyedSubtree(
            key: const ValueKey(2),
            child: _verdict(items: _twoItems),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScoreRow), findsNothing);
    });

    testWidgets('펼침: 높이는 바로 늘고 내역은 appear.seep, 접힘: disappear.seep 뒤 줄어듦', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_verdict(items: _twoItems)));
      final collapsed = tester.getSize(find.byKey(FortuneVerdict.cardKey));
      await tester.tapAt(_cardCorner(tester));
      await tester.pump();
      final expanded = tester.getSize(find.byKey(FortuneVerdict.cardKey));
      expect(expanded.height, greaterThan(collapsed.height));
      Opacity rowsOpacity() => tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(ScoreRow).first,
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(rowsOpacity().opacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(rowsOpacity().opacity, 1);
      expect(
        tester.getSize(find.byKey(FortuneVerdict.cardKey)).height,
        expanded.height,
      );
      // 접기: 사라지는 동안 자리는 그대로, 끝나면 줄어듦.
      await tester.tapAt(_cardCorner(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ScoreRow), findsNWidgets(2));
      expect(
        tester.getSize(find.byKey(FortuneVerdict.cardKey)).height,
        expanded.height,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScoreRow), findsNothing);
      expect(
        tester.getSize(find.byKey(FortuneVerdict.cardKey)).height,
        collapsed.height,
      );
    });

    testWidgets('동작 줄이기: 내역은 투명도만(흐림 없음)', (tester) async {
      await tester.pumpWidget(
        _app(_verdict(items: _twoItems), disableAnimations: true),
      );
      await tester.tapAt(_cardCorner(tester));
      await tester.pump();
      final filters = tester.widgetList<ImageFiltered>(
        find.ancestor(
          of: find.byType(ScoreRow).first,
          matching: find.byType(ImageFiltered),
        ),
      );
      expect(filters.where((f) => f.enabled), isEmpty);
      await tester.pumpAndSettle();
      expect(find.byType(ScoreRow), findsNWidgets(2));
    });

    testWidgets('카드 누름은 press.ink(카드 radius.lg)', (tester) async {
      await tester.pumpWidget(_app(_verdict(items: _twoItems)));
      final layer = inkLayer(find.byType(FortuneVerdict)).first;
      final gesture = await tester.startGesture(_cardCorner(tester));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(paintsInk(tester, layer), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('안내 줄: caption.lg text.secondary 가운데, 위 구분선, 터치 44, 카드 맨 아래', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_verdict(items: _twoItems)));
      final tokens = tester.element(find.byType(FortuneVerdict)).tokens;
      final l10n = _l10n(tester);
      final toggle = find.byKey(FortuneVerdict.toggleKey);
      final text = tester.widget<Text>(find.text(l10n.daySheetVerdictExpand));
      expect(text.style!.fontSize, tokens.typography.captionLg.fontSize);
      expect(text.style!.color, tokens.colors.textSecondary);
      final toggleRect = tester.getRect(toggle);
      expect(toggleRect.height, greaterThanOrEqualTo(44));
      expect(FortuneVerdict.toggleMinHeight, 44);
      final card = tester.getRect(find.byKey(FortuneVerdict.cardKey));
      expect(toggleRect.bottom, card.bottom);
      expect(
        tester.getCenter(find.text(l10n.daySheetVerdictExpand)).dx,
        lessThan(card.center.dx),
      );
      final iconFinder = find.descendant(
        of: toggle,
        matching: find.byType(Icon),
      );
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, tokens.colors.textSecondary);
      expect(
        icon.size,
        AppIconSize.adjacentText(tokens.typography.captionLg.fontSize!).logical,
      );
      // 글자와 꺾쇠 묶음이 가운데.
      final textRect = tester.getRect(find.text(l10n.daySheetVerdictExpand));
      final iconRect = tester.getRect(iconFinder);
      expect(iconRect.left - textRect.right, closeTo(Space.s4, 0.01));
      expect(
        (textRect.left + iconRect.right) / 2,
        closeTo(card.center.dx, 0.5),
      );
      // 위 구분선은 이름 아래 space.8.
      final divider = tester.getRect(find.byType(ListDivider).last);
      expect(divider.bottom, toggleRect.top);
      final names = tester.getRect(find.text(l10n.calendarLegendBodyGood));
      expect(divider.top - names.bottom, closeTo(Space.s8, 0.01));
    });

    testWidgets('스크린리더: 안내 줄은 펼침 상태가 있는 버튼, IA 슬롯 id', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_verdict(items: _twoItems)));
      final l10n = _l10n(tester);
      expect(
        tester.getSemantics(
          find.bySemanticsIdentifier(SlotIds.daySheetVerdictExpand),
        ),
        isSemantics(
          label: l10n.daySheetVerdictExpand,
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      await _toggle(tester);
      expect(
        tester.getSemantics(
          find.bySemanticsIdentifier(SlotIds.daySheetVerdictCollapse),
        ),
        isSemantics(
          label: l10n.daySheetVerdictCollapse,
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      // 스크린리더 누름도 접습니다.
      tester.semantics.tap(
        find.semantics.byPredicate(
          (node) => node.identifier == SlotIds.daySheetVerdictCollapse,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScoreRow), findsNothing);
      handle.dispose();
    });
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

  testWidgets('로딩 뼈: 막대 자리 한 줄뿐, 내역 뼈와 안내 줄 없음(V108)', (tester) async {
    await tester.pumpWidget(_app(FortuneVerdict.skeleton(animated: false)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(FortuneVerdict), findsNothing);
    expect(find.byType(SkeletonBone), findsOneWidget);
    expect(find.byType(ListDivider), findsNothing);
  });

  testWidgets('펼친 내역이 있어도 섹션 묶음이 줄 의미를 삼키지 않음', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_verdict(items: _twoItems)));
    await _toggle(tester);
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
