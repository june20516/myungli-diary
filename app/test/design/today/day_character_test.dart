import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

RenderedText _text(String value) =>
    RenderedText(segments: [Segment(text: value)]);

void main() {
  group('day-character', () {
    test('dayCharacterVariantOf는 날의 성격을 변형으로 옮깁니다', () {
      expect(
        dayCharacterVariantOf(DayKind.yongsinDay),
        DayCharacterVariant.good,
      );
      expect(
        dayCharacterVariantOf(DayKind.gwiinDay),
        DayCharacterVariant.gwiin,
      );
      expect(
        dayCharacterVariantOf(DayKind.gisinDay),
        DayCharacterVariant.gisin,
      );
      expect(
        dayCharacterVariantOf(DayKind.ordinaryDay),
        DayCharacterVariant.ordinary,
      );
    });

    testWidgets('Semantics 라벨은 배지 글자 + 이유입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: DayCharacter(
              variant: DayCharacterVariant.good,
              label: '좋은 날',
              reason: _text('오늘은 기운이 나를 돕는 날이에요.'),
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('좋은 날, 오늘은 기운이 나를 돕는 날이에요.'),
        findsOneWidget,
      );
    });

    testWidgets('reason이 없으면 이유 줄이 없고 라벨은 배지 글자뿐입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const Center(
            child: DayCharacter(
              variant: DayCharacterVariant.ordinary,
              label: '평범한 날',
            ),
          ),
        ),
      );
      expect(find.byKey(DayCharacter.reasonKey), findsNothing);
      expect(find.bySemanticsLabel('평범한 날'), findsOneWidget);
    });

    testWidgets('이유 줄 끝에 reasonTrailing이 붙고 눌립니다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: DayCharacter(
              variant: DayCharacterVariant.gwiin,
              label: '귀인의 날',
              reason: _text('도움을 주는 사람을 만나기 쉬워요.'),
              reasonTrailing: GestureDetector(
                onTap: () => tapped++,
                child: const Text('근거 보기 ›'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('근거 보기 ›'));
      expect(tapped, 1);
    });

    testWidgets('배지는 높이 26이고 변형마다 토큰 색을 씁니다', (tester) async {
      Future<BoxDecoration> badge(DayCharacterVariant variant) async {
        await tester.pumpWidget(
          inputApp(
            Center(
              child: DayCharacter(variant: variant, label: '날'),
            ),
          ),
        );
        return tester
                .widget<DecoratedBox>(find.byKey(DayCharacter.badgeKey))
                .decoration
            as BoxDecoration;
      }

      var decoration = await badge(DayCharacterVariant.good);
      final colors = tester
          .element(find.byKey(DayCharacter.badgeKey))
          .tokens
          .colors;
      expect(decoration.color, colors.badgeGoodBg);
      expect(tester.getSize(find.byKey(DayCharacter.badgeKey)).height, 26);

      decoration = await badge(DayCharacterVariant.gwiin);
      expect(decoration.color, colors.badgeGwiinBg);

      decoration = await badge(DayCharacterVariant.gisin);
      expect(decoration.color, colors.badgeGisinBg);

      decoration = await badge(DayCharacterVariant.ordinary);
      expect(decoration.color, isNull);
      expect(
        (decoration.border! as Border).top.color,
        colors.badgeOrdinaryBorder,
      );
      expect((decoration.border! as Border).top.width, 1);
    });
  });
}
