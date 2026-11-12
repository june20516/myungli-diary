import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/depth/weighing_note.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/text/line_height.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

const _text = '원전에서 신살은 사주를 판단하는 여러 단서 중 하나일 뿐이에요.';

Widget _note({double width = 312, double scale = 1}) => inputApp(
  MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: const WeighingNote(text: _text),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'fill.soft 상자, radius.md, 안쪽 space.12, caption.lg text.secondary',
    (tester) async {
      await tester.pumpWidget(_note());
      final tokens = tester.element(find.byType(WeighingNote)).tokens;
      final decoration =
          tester
                  .widget<DecoratedBox>(find.byKey(WeighingNote.boxKey))
                  .decoration
              as BoxDecoration;
      expect(decoration.color, tokens.colors.fillSoft);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(WeighingNote.radius)),
      );
      final text = tester.widget<Text>(find.text(_text));
      final caption = tokens.typography.captionLg;
      expect(text.style!.fontSize, caption.fontSize);
      expect(text.style!.color, tokens.colors.textSecondary);
      // 줄 수를 막지 않습니다(자르지 않음).
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      final box = tester.getRect(find.byKey(WeighingNote.boxKey));
      final textRect = tester.getRect(find.text(_text));
      expect(textRect.top - box.top, moreOrLessEquals(WeighingNote.padding));
    },
  );

  testWidgets('check Regular는 action.primary, 첫 줄 글줄 가운데, 글자와 space.8, 읽지 않음', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_note(width: 200));
    final tokens = tester.element(find.byType(WeighingNote)).tokens;
    final icon = tester.widget<AppIcon>(find.byType(AppIcon));
    expect(icon.weight, AppIconWeight.regular);
    expect(icon.color, tokens.colors.actionPrimary);
    expect(icon.icon, WeighingNote.glyph);
    final iconRect = tester.getRect(find.byType(Icon));
    final textRect = tester.getRect(find.text(_text));
    final lineHeight = lineHeightOf(
      tokens.typography.captionLg,
      TextScaler.noScaling,
    );
    // 좁은 폭에서 두 줄이어도 아이콘은 첫 줄 가운데에 있습니다.
    expect(textRect.height, greaterThan(lineHeight * 1.5));
    expect(
      iconRect.center.dy,
      moreOrLessEquals(textRect.top + lineHeight / 2, epsilon: 0.5),
    );
    expect(
      textRect.left - iconRect.right,
      moreOrLessEquals(WeighingNote.iconGap),
    );
    expect(find.bySemanticsLabel(_text), findsOneWidget);
    handle.dispose();
  });

  testWidgets('글자 배율 2.0에서는 두 줄을 넘어도 자르지 않고 문장 끝까지 보입니다', (tester) async {
    await tester.pumpWidget(_note(scale: 2));
    expect(tester.takeException(), isNull);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(_text), matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    final tokens = tester.element(find.byType(WeighingNote)).tokens;
    final lineHeight = lineHeightOf(
      tokens.typography.captionLg,
      const TextScaler.linear(2),
    );
    // 두 줄 상한을 넘어 줄이 늘고, 상자도 그만큼 커집니다.
    final textRect = tester.getRect(find.text(_text));
    expect(textRect.height, greaterThan(lineHeight * 2.5));
    final box = tester.getRect(find.byKey(WeighingNote.boxKey));
    expect(
      box.bottom - textRect.bottom,
      moreOrLessEquals(WeighingNote.padding),
    );
  });
}
