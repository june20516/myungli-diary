import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../../support/fonts.dart';
import '../input/input_harness.dart';

Widget _app(Widget child, {double textScale = 1}) => inputApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  ),
);

Finder get _dots => find.descendant(
  of: find.byKey(ScoreRow.dotsKey),
  matching: find.byType(DecoratedBox),
);

Color _dotColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_dots.first);
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  setUpAll(loadBundledFonts);

  group('점 개수', () {
    test('절댓값이고 최대 셋이며 넘으면 + 표시', () {
      expect(ScoreRow.dotCountOf(1), 1);
      expect(ScoreRow.dotCountOf(-2), 2);
      expect(ScoreRow.dotCountOf(3), 3);
      expect(ScoreRow.dotCountOf(4), 3);
      expect(ScoreRow.dotCountOf(-5), 3);
      expect(ScoreRow.overflowsOf(3), isFalse);
      expect(ScoreRow.overflowsOf(-4), isTrue);
    });
  });

  group('ScoreRow.verdict', () {
    Widget row({int score = 2, VoidCallback? onTagTap, String? meaning}) =>
        _app(
          ScoreRow.verdict(
            glyph: '用',
            name: '용신의 날',
            meaning: meaning ?? '나를 돕는 기운이 든 날',
            score: score,
            onTagTap: onTagTap,
          ),
        );

    testWidgets('더함: + 부호, 점 둘은 badge.good.bg, 태그는 good 톤', (tester) async {
      await tester.pumpWidget(row());
      final tokens = tester.element(find.byType(ScoreRow)).tokens;
      expect(
        tester.widget<Text>(find.byKey(ScoreRow.signKey)).data,
        ScoreRow.plusSign,
      );
      expect(ScoreRow.plusSign.codeUnits, [0x2B]);
      expect(_dots, findsNWidgets(2));
      expect(_dotColor(tester), tokens.colors.badgeGoodBg);
      expect(
        tester.widget<HanjaTag>(find.byType(HanjaTag)).tone,
        HanjaTagTone.good,
      );
      final dot = tester.getSize(_dots.first);
      expect(dot, const Size(8, 8));
    });

    testWidgets('뺌: U+2212 부호, text.secondary 점, bad 톤', (tester) async {
      await tester.pumpWidget(row(score: -1));
      final tokens = tester.element(find.byType(ScoreRow)).tokens;
      expect(ScoreRow.minusSign.codeUnits, [0x2212]);
      expect(
        tester.widget<Text>(find.byKey(ScoreRow.signKey)).data,
        ScoreRow.minusSign,
      );
      expect(_dots, findsOneWidget);
      expect(_dotColor(tester), tokens.colors.textSecondary);
      expect(
        tester.widget<HanjaTag>(find.byType(HanjaTag)).tone,
        HanjaTagTone.bad,
      );
    });

    testWidgets('점수 4: 점 셋 뒤에 + 글자', (tester) async {
      await tester.pumpWidget(row(score: 4));
      expect(_dots, findsNWidgets(3));
      expect(find.byKey(ScoreRow.overflowKey), findsOneWidget);
    });

    testWidgets('점수 3: 점 셋, + 글자 없음', (tester) async {
      await tester.pumpWidget(row(score: 3));
      expect(_dots, findsNWidgets(3));
      expect(find.byKey(ScoreRow.overflowKey), findsNothing);
    });

    testWidgets('줄 최소 높이 48, 뜻은 두 줄까지', (tester) async {
      await tester.pumpWidget(row());
      expect(
        tester.getSize(find.byType(ScoreRow)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.widget<Text>(find.byKey(ScoreRow.meaningKey)).maxLines, 2);
    });

    testWidgets('태그를 누르면 onTagTap, 없으면 누를 수 없음', (tester) async {
      var taps = 0;
      await tester.pumpWidget(row(onTagTap: () => taps++));
      await tester.tap(find.byType(HanjaTag));
      expect(taps, 1);

      await tester.pumpWidget(row());
      expect(tester.widget<HanjaTag>(find.byType(HanjaTag)).onTap, isNull);
    });

    testWidgets('스크린리더: 이름, 뜻, 더함 둘 묶음과 따로 버튼인 태그', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(row(onTagTap: () {}));
      final l10n = AppLocalizations.of(tester.element(find.byType(ScoreRow)));
      expect(
        find.bySemanticsLabel(
          '용신의 날, 나를 돕는 기운이 든 날, ${l10n.daySheetVerdictItemPlus(2)}',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('용신의 날').last),
        isSemantics(label: '용신의 날', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('뺌은 조심할 쪽으로 읽음', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(row(score: -3));
      final l10n = AppLocalizations.of(tester.element(find.byType(ScoreRow)));
      expect(
        find.bySemanticsLabel(
          '용신의 날, 나를 돕는 기운이 든 날, ${l10n.daySheetVerdictItemMinus(3)}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('글자 $scale배에서 넘치지 않음', (tester) async {
        await tester.pumpWidget(
          _app(
            const ScoreRow.verdict(
              glyph: '沖',
              name: '일지나 월지와의 충',
              meaning: '내 사주의 일지나 월지와 부딪히는 기운이 들어와 흐름이 거칠어질 수 있는 날',
              score: -2,
            ),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ScoreRow.rule', () {
    testWidgets('뜻 없음, 누를 수 없음, 위아래 space.8, 최소 높이 없음', (tester) async {
      await tester.pumpWidget(
        _app(const ScoreRow.rule(glyph: '合', name: '합', score: 1)),
      );
      expect(find.byKey(ScoreRow.meaningKey), findsNothing);
      expect(tester.widget<HanjaTag>(find.byType(HanjaTag)).onTap, isNull);
      final tag = tester.getSize(find.byType(HanjaTag));
      expect(
        tester.getSize(find.byType(ScoreRow)).height,
        tag.height + Space.s8 * 2,
      );
    });

    testWidgets('스크린리더: 이름과 더함 개수 한 덩어리', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const ScoreRow.rule(glyph: '忌', name: '기신의 날', score: -1)),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(ScoreRow)));
      expect(
        find.bySemanticsLabel('기신의 날, ${l10n.daySheetVerdictItemMinus(1)}'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  testWidgets('로딩 뼈는 줄 높이 48 이상', (tester) async {
    await tester.pumpWidget(_app(ScoreRow.skeleton(animated: false)));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ConstrainedBox).last).height,
      greaterThanOrEqualTo(ScoreRow.minHeight),
    );
    expect(ScoreRow.minHeight, 48);
  });

  testWidgets('rule: 글자 2배 긴 이름에서도 태그와 부호 사이 12를 남김', (tester) async {
    await tester.pumpWidget(
      _app(
        const ScoreRow.rule(glyph: '沖', name: '일지나 월지와의 충', score: -2),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    final tag = tester.getRect(find.byType(HanjaTag));
    final sign = tester.getRect(find.byKey(ScoreRow.signKey));
    expect(sign.left - tag.right, greaterThanOrEqualTo(12));
  });

  testWidgets('verdict: 긴 영어 이름, 글자 2배, 폭 320에서 넘치지 않음', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: inputApp(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: ScoreRow.verdict(
                glyph: '沖',
                name: 'Clash with the day or month branch',
                meaning:
                    'A clashing energy arrives and the flow may turn rough',
                score: -2,
              ),
            ),
          ),
          locale: const Locale('en'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byType(HanjaTag),
        matching: find.text('Clash with the day or month branch'),
      ),
    );
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.maxLines, 1);
    final row = tester.getRect(find.byType(ScoreRow));
    expect(
      tester.getRect(find.byType(HanjaTag)).right,
      lessThanOrEqualTo(row.right),
    );
    expect(
      tester.getRect(find.byType(HanjaTag)).right + 12,
      lessThanOrEqualTo(tester.getRect(find.byKey(ScoreRow.signKey)).left),
    );
  });

  testWidgets('verdict: 짧은 태그면 뜻 칸이 나머지 폭을 모두 씀', (tester) async {
    await tester.pumpWidget(
      _app(
        const ScoreRow.verdict(
          glyph: '合',
          name: '합',
          meaning: '짧은 뜻',
          score: 1,
        ),
      ),
    );
    final tag = tester.getRect(find.byType(HanjaTag));
    final cell = tester.getRect(find.byKey(ScoreRow.meaningCellKey));
    final sign = tester.getRect(find.byKey(ScoreRow.signKey));
    expect(cell.left, tag.right);
    expect(cell.right, sign.left - 12);
  });

  testWidgets('점수 4를 읽는 개수는 점과 같은 셋', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const ScoreRow.rule(glyph: '用', name: '용신의 날', score: 4)),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(ScoreRow)));
    expect(
      find.bySemanticsLabel('용신의 날, ${l10n.daySheetVerdictItemPlus(3)}'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
