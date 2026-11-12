import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/day_virtue_kind.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god_group.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(HanjaTag.surfaceKey)).decoration
        as BoxDecoration;

void main() {
  Future<void> pump(
    WidgetTester tester,
    HanjaTag tag, {
    Brightness brightness = Brightness.light,
  }) => tester
      .pumpWidget(
        inputApp(
          Align(alignment: Alignment.centerLeft, child: tag),
          brightness: brightness,
        ),
      )
      .then((_) => tester.pumpAndSettle());

  group('치수', () {
    testWidgets('알약 높이 30, 한자 원 22, 왼쪽 4, 원과 이름 4, 오른쪽 12', (tester) async {
      await pump(tester, const HanjaTag(glyph: '沖', label: '충'));
      final pill = tester.getRect(find.byKey(HanjaTag.surfaceKey));
      final circle = tester.getRect(find.byKey(HanjaTag.glyphKey));
      final name = tester.getRect(find.text('충'));
      expect(pill.height, 30);
      expect(circle.size, const Size(22, 22));
      expect(circle.left - pill.left, 4);
      expect(circle.center.dy, pill.center.dy);
      expect(name.left - circle.right, 4);
      expect(pill.right - name.right, 12);
    });

    testWidgets('compact는 알약 22, 한자 원 16, 왼쪽 4, 원과 이름 2, 오른쪽 8', (
      tester,
    ) async {
      await pump(
        tester,
        const HanjaTag(
          glyph: '德',
          label: '천덕일',
          tone: HanjaTagTone.good,
          size: HanjaTagSize.compact,
        ),
      );
      final pill = tester.getRect(find.byKey(HanjaTag.surfaceKey));
      final circle = tester.getRect(find.byKey(HanjaTag.glyphKey));
      final name = tester.getRect(find.text('천덕일'));
      expect(pill.height, 22);
      expect(circle.size, const Size(16, 16));
      expect(circle.left - pill.left, 4);
      expect(circle.center.dy, pill.center.dy);
      expect(name.left - circle.right, 2);
      expect(pill.right - name.right, 8);
      expect(
        tester.widget<Text>(find.text('德')).style!.fontWeight,
        FontWeight.w700,
      );
    });

    testWidgets('compact selected는 크기가 그대로이고 선택 테두리입니다', (tester) async {
      await pump(
        tester,
        const HanjaTag(
          glyph: '德',
          label: '천덕일',
          tone: HanjaTagTone.good,
          size: HanjaTagSize.compact,
        ),
      );
      final plain = tester.getSize(find.byKey(HanjaTag.surfaceKey));
      await pump(
        tester,
        const HanjaTag(
          glyph: '德',
          label: '천덕일',
          tone: HanjaTagTone.good,
          size: HanjaTagSize.compact,
          variant: HanjaTagVariant.selected,
        ),
      );
      expect(tester.getSize(find.byKey(HanjaTag.surfaceKey)), plain);
      final tokens = tester.element(find.byKey(HanjaTag.surfaceKey)).tokens;
      expect(
        _decoration(tester).border,
        Border.all(
          color: tokens.colors.actionPrimary,
          width: HanjaTag.selectedBorderWidth,
        ),
      );
      expect(_decoration(tester).color, tokens.colors.tagGoodBg);
    });

    testWidgets('한자는 12 700이고 원은 bg.sheet입니다', (tester) async {
      await pump(tester, const HanjaTag(glyph: '沖', label: '충'));
      final style = tester.widget<Text>(find.text('沖')).style!;
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w700);
      final circle =
          tester.widget<DecoratedBox>(find.byKey(HanjaTag.glyphKey)).decoration
              as BoxDecoration;
      final tokens = tester.element(find.byKey(HanjaTag.glyphKey)).tokens;
      expect(circle.color, tokens.colors.bgSheet);
      expect(circle.shape, BoxShape.circle);
    });

    testWidgets('큰 글자에서도 한자 원은 22 그대로이고 이름 한 줄', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: inputApp(
            const Align(
              alignment: Alignment.topLeft,
              child: HanjaTag(glyph: '沖', label: '일지 충'),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(HanjaTag.glyphKey)), const Size(22, 22));
      expect(
        tester.getSize(find.byKey(HanjaTag.surfaceKey)).height,
        greaterThanOrEqualTo(30),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('skeleton은 폭 64, 높이 30입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Align(
            alignment: Alignment.topLeft,
            child: HanjaTag.skeleton(animated: false),
          ),
        ),
      );
      final size = tester.getSize(find.byType(SizedBox).last);
      expect(size, const Size(64, 30));
    });
  });

  group('톤과 변형', () {
    testWidgets('term은 term.bg와 term.fg 초록입니다', (tester) async {
      await pump(tester, const HanjaTag(glyph: '合', label: '합'));
      final tokens = tester.element(find.byKey(HanjaTag.surfaceKey)).tokens;
      expect(_decoration(tester).color, tokens.colors.termBg);
      expect(
        tester.widget<Text>(find.text('합')).style!.color,
        tokens.colors.termFg,
      );
    });

    testWidgets('기본 변형의 날의 성격은 tag.* 톤입니다', (tester) async {
      for (final (tone, bg, fg) in [
        (HanjaTagTone.yongsin, 'tagGoodBg', 'tagGoodFg'),
        (HanjaTagTone.gwiin, 'tagGoodBg', 'tagGoodFg'),
        (HanjaTagTone.gisin, 'tagBadBg', 'tagBadFg'),
      ]) {
        await pump(tester, HanjaTag(glyph: '用', label: '이름', tone: tone));
        final colors = tester
            .element(find.byKey(HanjaTag.surfaceKey))
            .tokens
            .colors;
        final expectedBg = bg == 'tagGoodBg'
            ? colors.tagGoodBg
            : colors.tagBadBg;
        final expectedFg = fg == 'tagGoodFg'
            ? colors.tagGoodFg
            : colors.tagBadFg;
        expect(_decoration(tester).color, expectedBg, reason: '$tone');
        expect(
          tester.widget<Text>(find.text('이름')).style!.color,
          expectedFg,
          reason: '$tone',
        );
      }
    });

    testWidgets('평범한 날은 바탕 없이 1px tag.neutral 테두리입니다', (tester) async {
      await pump(
        tester,
        const HanjaTag(glyph: '平', label: '평범한 날', tone: HanjaTagTone.ordinary),
      );
      final colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      final decoration = _decoration(tester);
      expect(decoration.color, isNull);
      expect(decoration.border, Border.all(color: colors.tagNeutralBorder));
    });

    testWidgets('good, bad는 verdictTone(tag.good, tag.bad)입니다', (tester) async {
      await pump(
        tester,
        const HanjaTag(glyph: '沖', label: '충', tone: HanjaTagTone.bad),
      );
      final colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(_decoration(tester).color, colors.tagBadBg);
    });

    testWidgets('emphasis 용신의 날은 badge.good 진한 채움이고 한자는 바탕색입니다', (
      tester,
    ) async {
      await pump(
        tester,
        const HanjaTag(
          glyph: '用',
          label: '용신의 날',
          tone: HanjaTagTone.yongsin,
          variant: HanjaTagVariant.emphasis,
        ),
      );
      final colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(_decoration(tester).color, colors.badgeGoodBg);
      expect(
        tester.widget<Text>(find.text('용신의 날')).style!.color,
        colors.badgeGoodFg,
      );
      expect(
        tester.widget<Text>(find.text('用')).style!.color,
        colors.badgeGoodBg,
      );
    });

    testWidgets('emphasis 귀인, 기신, 평범은 V8 배지 매핑입니다', (tester) async {
      await pump(
        tester,
        const HanjaTag(
          glyph: '貴',
          label: '귀인의 날',
          tone: HanjaTagTone.gwiin,
          variant: HanjaTagVariant.emphasis,
        ),
      );
      var colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(_decoration(tester).color, colors.badgeGwiinBg);
      expect(
        tester.widget<Text>(find.text('貴')).style!.color,
        colors.badgeGwiinFg,
      );

      await pump(
        tester,
        const HanjaTag(
          glyph: '忌',
          label: '기신의 날',
          tone: HanjaTagTone.gisin,
          variant: HanjaTagVariant.emphasis,
        ),
      );
      colors = tester.element(find.byKey(HanjaTag.surfaceKey)).tokens.colors;
      expect(_decoration(tester).color, colors.badgeGisinBg);

      await pump(
        tester,
        const HanjaTag(
          glyph: '平',
          label: '평범한 날',
          tone: HanjaTagTone.ordinary,
          variant: HanjaTagVariant.emphasis,
        ),
      );
      colors = tester.element(find.byKey(HanjaTag.surfaceKey)).tokens.colors;
      expect(_decoration(tester).color, isNull);
      expect(
        _decoration(tester).border,
        Border.all(color: colors.badgeOrdinaryBorder),
      );
    });

    testWidgets('selected는 안쪽 1.5px action.primary 테두리이고 크기가 그대로입니다', (
      tester,
    ) async {
      await pump(tester, const HanjaTag(glyph: '合', label: '합'));
      final plain = tester.getSize(find.byKey(HanjaTag.surfaceKey));
      await pump(
        tester,
        const HanjaTag(
          glyph: '合',
          label: '합',
          variant: HanjaTagVariant.selected,
        ),
      );
      final colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(
        _decoration(tester).border,
        Border.all(color: colors.actionPrimary, width: 1.5),
      );
      expect(tester.getSize(find.byKey(HanjaTag.surfaceKey)), plain);
    });

    testWidgets('selected 평범한 날은 톤 테두리 대신 선택 테두리입니다', (tester) async {
      await pump(
        tester,
        const HanjaTag(
          glyph: '平',
          label: '평범한 날',
          tone: HanjaTagTone.ordinary,
          variant: HanjaTagVariant.selected,
        ),
      );
      final colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(
        _decoration(tester).border,
        Border.all(color: colors.actionPrimary, width: 1.5),
      );
    });

    testWidgets('ganji는 그 글자 오행의 bg, fg이고 원은 bg.sheet 위 오행 glyph 색입니다', (
      tester,
    ) async {
      await pump(
        tester,
        const HanjaTag(glyph: '未', label: '미시', variant: HanjaTagVariant.ganji),
      );
      final colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(_decoration(tester).color, colors.ohaengEarthBg);
      expect(
        tester.widget<Text>(find.text('미시')).style!.color,
        colors.ohaengEarthFg,
      );
      expect(
        tester.widget<Text>(find.text('未')).style!.color,
        colors.ohaengEarthGlyph,
      );
      expect(_decoration(tester).border, isNull);
    });

    testWidgets('ganji 금과 수 알약은 1px 안쪽 테두리, 다크 금 한자는 알약 바탕색입니다 (V98)', (
      tester,
    ) async {
      await pump(
        tester,
        const HanjaTag(glyph: '亥', label: '해시', variant: HanjaTagVariant.ganji),
      );
      final light = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(
        _decoration(tester).border,
        Border.all(color: light.ohaengWaterBorder),
      );
      expect(
        tester.widget<Text>(find.text('亥')).style!.color,
        light.ohaengWaterGlyph,
      );

      await pump(
        tester,
        const HanjaTag(glyph: '申', label: '신시', variant: HanjaTagVariant.ganji),
        brightness: Brightness.dark,
      );
      final dark = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(
        _decoration(tester).border,
        Border.all(color: dark.ohaengMetalBorder),
      );
      expect(
        tester.widget<Text>(find.text('申')).style!.color,
        dark.ohaengMetalGlyph,
      );
    });

    testWidgets('ganji에 간지가 아닌 글자가 오면 예외 없이 term 톤으로 그립니다', (tester) async {
      await pump(
        tester,
        const HanjaTag(glyph: '貴', label: '귀', variant: HanjaTagVariant.ganji),
      );
      final colors = tester
          .element(find.byKey(HanjaTag.surfaceKey))
          .tokens
          .colors;
      expect(tester.takeException(), isNull);
      expect(_decoration(tester).color, colors.termBg);
    });

    testWidgets('다크 모드는 라이트와 다른 색을 칠합니다', (tester) async {
      await pump(tester, const HanjaTag(glyph: '合', label: '합'));
      final light = _decoration(tester).color;
      await pump(
        tester,
        const HanjaTag(glyph: '合', label: '합'),
        brightness: Brightness.dark,
      );
      expect(_decoration(tester).color, isNot(light));
    });
  });

  group('의미와 눌림', () {
    testWidgets('semantics 이름은 label만이고 한자는 읽지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const HanjaTag(glyph: '沖', label: '충'));
      expect(find.bySemanticsLabel('충'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('沖')), findsNothing);
      handle.dispose();
    });

    testWidgets('onTap이 있으면 button이고 누르면 호출됩니다', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pump(tester, HanjaTag(glyph: '沖', label: '충', onTap: () => taps++));
      expect(
        tester.getSemantics(find.bySemanticsLabel('충')),
        isSemantics(label: '충', isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byKey(HanjaTag.surfaceKey));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('onTap이 없으면 button이 아니고 터치 영역을 넓히지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const HanjaTag(glyph: '沖', label: '충'));
      expect(
        tester.getSemantics(find.bySemanticsLabel('충')),
        isSemantics(label: '충', isButton: false),
      );
      expect(find.byType(VerticalHitSlop), findsNothing);
      handle.dispose();
    });

    testWidgets('compact도 눌리는 영역은 위아래로 44까지 넓습니다', (tester) async {
      HanjaTag tag(VoidCallback onTap) => HanjaTag(
        glyph: '德',
        label: '천덕일',
        tone: HanjaTagTone.good,
        size: HanjaTagSize.compact,
        onTap: onTap,
      );
      var taps = 0;
      await pump(tester, tag(() => taps++));
      final pill = tester.getRect(find.byKey(HanjaTag.surfaceKey));
      expect(pill.height, 22);
      await tester.tapAt(Offset(pill.center.dx, pill.top - 10));
      await tester.tapAt(Offset(pill.center.dx, pill.bottom + 10));
      expect(taps, 2);
      await tester.tapAt(Offset(pill.center.dx, pill.top - 12));
      expect(taps, 2);
    });

    testWidgets('눌리는 영역은 위아래로 44까지 넓습니다', (tester) async {
      await pump(tester, HanjaTag(glyph: '沖', label: '충', onTap: () {}));
      final pill = tester.getRect(find.byKey(HanjaTag.surfaceKey));
      var taps = 0;
      await pump(tester, HanjaTag(glyph: '沖', label: '충', onTap: () => taps++));
      await tester.tapAt(Offset(pill.center.dx, pill.top - 6));
      expect(taps, 1);
    });
  });

  group('글자표', () {
    test('날의 성격 넷의 글자와 톤', () {
      expect(
        {for (final kind in DayKind.values) kind: HanjaGlyphs.forDayKind(kind)},
        {
          DayKind.gwiinDay: '貴',
          DayKind.yongsinDay: '用',
          DayKind.gisinDay: '忌',
          DayKind.ordinaryDay: '平',
        },
      );
      expect(
        {
          for (final kind in DayKind.values)
            kind: HanjaGlyphs.toneOfDayKind(kind),
        },
        {
          DayKind.gwiinDay: HanjaTagTone.gwiin,
          DayKind.yongsinDay: HanjaTagTone.yongsin,
          DayKind.gisinDay: HanjaTagTone.gisin,
          DayKind.ordinaryDay: HanjaTagTone.ordinary,
        },
      );
    });

    test('십성 묶음 다섯의 글자', () {
      expect(
        {
          for (final group in TenGodGroup.values)
            group: HanjaGlyphs.forTenGodGroup(group),
        },
        {
          TenGodGroup.bigyeop: '比',
          TenGodGroup.siksang: '食',
          TenGodGroup.jaeseong: '財',
          TenGodGroup.gwanseong: '官',
          TenGodGroup.inseong: '印',
        },
      );
    });

    test('태그 키의 글자', () {
      expect(HanjaGlyphs.forTagKey('harmony'), '合');
      expect(HanjaGlyphs.forTagKey('clash'), '沖');
      expect(HanjaGlyphs.forTagKey('clash_day_branch'), '沖');
      expect(HanjaGlyphs.forTagKey('clash_month_branch'), '沖');
      expect(HanjaGlyphs.forTagKey('hyeong'), '刑');
      expect(HanjaGlyphs.forTagKey('cheoneul_gwiin'), '天');
      expect(HanjaGlyphs.forTagKey('dohwa'), '桃');
      expect(HanjaGlyphs.forTagKey('yeokma'), '驛');
      expect(HanjaGlyphs.forTagKey('hwagae'), '華');
      expect(HanjaGlyphs.forTagKey('gongmang'), '空');
      expect(HanjaGlyphs.forTagKey('gosin'), '孤');
      expect(HanjaGlyphs.forTagKey('gwasuk'), '寡');
      expect(HanjaGlyphs.forTagKey('wonjin'), '元');
      expect(HanjaGlyphs.forTagKey('yongsin_day'), '用');
      expect(HanjaGlyphs.forTagKey('gwiin_day'), '貴');
    });

    test('덕일은 두 덕 모두 德이고 모르는 덕은 null입니다', () {
      expect(HanjaGlyphs.forDayVirtue(DayVirtueKind.cheondeokDay), '德');
      expect(HanjaGlyphs.forDayVirtue(DayVirtueKind.woldeokDay), '德');
      expect(
        HanjaGlyphs.forDayVirtue(DayVirtueKind.unknownDefaultOpenApi),
        isNull,
      );
    });

    test('십성 몰림 태그는 그 묶음 글자입니다', () {
      for (final group in TenGodGroup.values) {
        expect(
          HanjaGlyphs.forTagKey('ten_god_rush.${group.value}'),
          HanjaGlyphs.forTenGodGroup(group),
        );
      }
      expect(HanjaGlyphs.forTagKey('ten_god_rush.siksang'), '食');
    });

    test('점수 항목 id의 글자', () {
      expect(
        {
          for (final id in [
            'yongsin_day',
            'gwiin_day',
            'hap',
            'gisin_day',
            'chung_day_or_month',
            'chung_other',
            'hyeong',
          ])
            id: HanjaGlyphs.forScoreItem(id),
        },
        {
          'yongsin_day': '用',
          'gwiin_day': '貴',
          'hap': '合',
          'gisin_day': '忌',
          'chung_day_or_month': '沖',
          'chung_other': '沖',
          'hyeong': '刑',
        },
      );
    });

    test('모르는 키는 null입니다', () {
      expect(HanjaGlyphs.forTagKey('unknown_tag'), isNull);
      expect(HanjaGlyphs.forTagKey('ten_god_rush.unknown'), isNull);
      expect(HanjaGlyphs.forTagKey('ten_god_rush'), isNull);
      expect(HanjaGlyphs.forTagKey(''), isNull);
      expect(HanjaGlyphs.forScoreItem('unknown'), isNull);
    });
  });
}
