import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/open_ring.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

/// [chip] 아래 첫 [DecoratedBox]의 테두리. 없으면 null입니다.
Border? _borderOf(WidgetTester tester, Finder chip) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(of: chip, matching: find.byType(DecoratedBox)),
  );
  for (final box in boxes) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.border as Border?;
    }
  }
  return null;
}

void main() {
  group('open.ring (V129)', () {
    testWidgets('term-token: 연 시트가 열린 동안만 안쪽 1.5px action.primary 테두리입니다', (
      tester,
    ) async {
      final sheet = Completer<void>();
      await tester.pumpWidget(
        inputApp(
          Center(
            child: TermToken(
              label: '식신',
              variant: TermTokenVariant.inline,
              onTap: () => sheet.future,
            ),
          ),
        ),
      );
      final chip = find.byType(TermToken);
      expect(_borderOf(tester, chip), isNull, reason: '누르기 전');

      await tester.tap(chip);
      await tester.pump();
      final border = _borderOf(tester, chip)!;
      final primary = tester.element(chip).tokens.colors.actionPrimary;
      expect(border.top.color, primary);
      expect(border.top.width, OpenRing.width);
      expect(border.top.strokeAlign, BorderSide.strokeAlignInside);

      sheet.complete();
      await tester.pump();
      expect(_borderOf(tester, chip), isNull, reason: '시트가 닫히면 사라짐');
    });

    testWidgets('누름이 Future를 돌려주지 않으면 열림 표시가 없습니다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: TermToken(
              label: '정관',
              variant: TermTokenVariant.label,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TermToken));
      await tester.pump();
      expect(taps, 1);
      expect(_borderOf(tester, find.byType(TermToken)), isNull);
    });

    testWidgets('hanja-tag: 연 시트가 열린 동안 selected 테두리이고 닫히면 원래 변형입니다', (
      tester,
    ) async {
      final sheet = Completer<void>();
      await tester.pumpWidget(
        inputApp(
          Center(
            child: HanjaTag(glyph: '食', label: '식신', onTap: () => sheet.future),
          ),
        ),
      );
      final tag = find.byType(HanjaTag);
      Border? border() =>
          (tester
                          .widget<DecoratedBox>(find.byKey(HanjaTag.surfaceKey))
                          .decoration
                      as BoxDecoration)
                  .border
              as Border?;
      final primary = tester.element(tag).tokens.colors.actionPrimary;
      expect(border()?.top.color, isNot(primary));

      await tester.tap(tag);
      await tester.pump();
      expect(border()!.top.color, primary);
      expect(border()!.top.width, HanjaTag.selectedBorderWidth);

      sheet.complete();
      await tester.pump();
      expect(border()?.top.color, isNot(primary));
    });
  });
}
