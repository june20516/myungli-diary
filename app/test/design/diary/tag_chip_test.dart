import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

BoxDecoration _surface(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(TagChip.surfaceKey)).decoration
        as BoxDecoration;

Widget _chip(TagChipVariant variant, {VoidCallback? onTap}) => inputApp(
  Center(
    child: TagChip(name: '천을귀인', variant: variant, onTap: onTap),
  ),
);

void main() {
  group('tag-chip', () {
    testWidgets('"#이름"이고 높이 26·radius.full·label.md 12·좌우 10입니다', (
      tester,
    ) async {
      await tester.pumpWidget(_chip(TagChipVariant.good));
      final text = tester.widget<Text>(find.text('#천을귀인'));
      final tokens = tester.element(find.byType(TagChip)).tokens;
      expect(text.style!.fontSize, 12);
      expect(text.style!.fontWeight, tokens.typography.labelMd.fontWeight);
      expect(tester.getSize(find.byKey(TagChip.surfaceKey)).height, 26);
      expect(
        _surface(tester).borderRadius,
        const BorderRadius.all(Radius.circular(Radii.full)),
      );
      final surfaceLeft = tester.getTopLeft(find.byKey(TagChip.surfaceKey)).dx;
      expect(tester.getTopLeft(find.text('#천을귀인')).dx - surfaceLeft, 10);
    });

    testWidgets('변형별 바탕·글자: good·bad는 채움, neutral은 1px 테두리만', (tester) async {
      for (final variant in TagChipVariant.values) {
        await tester.pumpWidget(_chip(variant));
        final colors = tester.element(find.byType(TagChip)).tokens.colors;
        final decoration = _surface(tester);
        final fg = tester.widget<Text>(find.text('#천을귀인')).style!.color;
        switch (variant) {
          case TagChipVariant.good:
            expect(decoration.color, colors.tagGoodBg);
            expect(fg, colors.tagGoodFg);
            expect(decoration.border, isNull);
          case TagChipVariant.bad:
            expect(decoration.color, colors.tagBadBg);
            expect(fg, colors.tagBadFg);
            expect(decoration.border, isNull);
          case TagChipVariant.neutral:
            expect(decoration.color, isNull);
            expect(
              decoration.border,
              Border.all(color: colors.tagNeutralBorder),
            );
            expect(fg, colors.tagNeutralFg);
        }
      }
    });

    test('길흉 값으로 변형을 고릅니다', () {
      expect(
        TagChipVariant.ofPolarity(TagPolarityEnum.good),
        TagChipVariant.good,
      );
      expect(
        TagChipVariant.ofPolarity(TagPolarityEnum.bad),
        TagChipVariant.bad,
      );
      expect(
        TagChipVariant.ofPolarity(TagPolarityEnum.neutral),
        TagChipVariant.neutral,
      );
    });

    testWidgets('스크린리더: 링크, "#이름, 길흉 낱말"이고 누르면 onTap, 터치 높이 44', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(_chip(TagChipVariant.bad, onTap: () => taps++));
      final data = tester
          .getSemantics(find.bySemanticsLabel('#천을귀인, 조심할 흐름'))
          .getSemanticsData();
      expect(data.flagsCollection.isLink, isTrue);
      expect(
        tester.getSize(find.byKey(TagChip.surfaceKey)).height,
        26,
        reason: '보이는 모양은 그대로',
      );
      // 칩 위 9px 지점도 눌립니다(위아래 9px 넓힘).
      final top = tester.getRect(find.byKey(TagChip.surfaceKey)).topCenter;
      await tester.tapAt(top.translate(0, -8));
      await tester.pumpAndSettle();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('onTap이 없으면 누를 수 없는 표시이고 라벨은 그대로입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_chip(TagChipVariant.neutral));
      final data = tester.getSemantics(find.byType(TagChip)).getSemanticsData();
      expect(data.flagsCollection.isLink, isFalse);
      expect(data.label, '#천을귀인, 무난한 흐름');
      handle.dispose();
    });

    testWidgets('pressed: 누르는 동안 press.ink 얼룩이 번집니다', (tester) async {
      await tester.pumpWidget(_chip(TagChipVariant.good, onTap: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TagChip)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(inkLayer(find.byType(TagChip)), findsWidgets);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('글자 2배에서도 잘리지 않고 칩이 커집니다(최소 높이)', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _chip(TagChipVariant.good),
        ),
      );
      expect(
        tester.getSize(find.byKey(TagChip.surfaceKey)).height,
        greaterThan(26),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
