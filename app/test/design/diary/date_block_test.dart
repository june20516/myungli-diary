import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/diary/date_block.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

Widget _block({
  IljinText? iljin = const IljinText(shown: '癸未(계미)일', spoken: '계미일'),
  bool iljinLoading = false,
}) => inputApp(
  Align(
    alignment: Alignment.topLeft,
    child: DateBlock(
      day: '5',
      monthWeekday: '11월 목요일',
      iljin: iljin,
      iljinLoading: iljinLoading,
    ),
  ),
);

void main() {
  group('date-block', () {
    testWidgets(
      '일 숫자 44 700 고정폭, 옆 12에 월과 요일(label.lg), 아래 2에 일진(caption.md)',
      (tester) async {
        await tester.pumpWidget(_block());
        final tokens = tester.element(find.byType(DateBlock)).tokens;
        final day = tester.widget<Text>(find.text('5'));
        expect(day.style!.fontSize, DateBlock.dayFontSize);
        expect(DateBlock.dayFontSize, 44);
        expect(day.style!.fontWeight, FontWeight.w700);
        expect(day.style!.height, 1);
        expect(day.style!.color, tokens.colors.textPrimary);
        expect(
          day.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );

        final month = tester.widget<Text>(find.text('11월 목요일'));
        expect(month.style!.fontSize, tokens.typography.labelLg.fontSize);
        expect(month.style!.color, tokens.colors.textPrimary);
        expect(
          tester.getTopLeft(find.text('11월 목요일')).dx -
              tester.getTopRight(find.text('5')).dx,
          Space.s12,
        );

        final iljin = find.byKey(DateBlock.iljinKey);
        expect(
          tester.getTopLeft(iljin).dy -
              tester.getBottomLeft(find.text('11월 목요일')).dy,
          Space.s2,
        );
        final rich = tester.widget<Text>(iljin);
        expect(rich.textSpan!.style!.color, tokens.colors.textSecondary);
        expect(
          rich.textSpan!.style!.fontSize,
          tokens.typography.captionMd.fontSize,
        );
        // 한자는 font.family.hanja입니다.
        final hanja = (rich.textSpan! as TextSpan).children!.first as TextSpan;
        expect(hanja.text, '癸未');
        expect(
          hanja.style!.fontFamily,
          tokens.typography.hanjaPillar.fontFamily,
        );
      },
    );

    testWidgets('오른쪽 두 줄 묶음은 숫자와 세로 가운데입니다', (tester) async {
      await tester.pumpWidget(_block());
      final dayCenter = tester.getCenter(find.text('5')).dy;
      final top = tester.getTopLeft(find.text('11월 목요일')).dy;
      final bottom = tester.getBottomLeft(find.byKey(DateBlock.iljinKey)).dy;
      expect((top + bottom) / 2, moreOrLessEquals(dayCenter, epsilon: 0.5));
    });

    testWidgets('일진이 없으면 그 줄만 그리지 않습니다', (tester) async {
      await tester.pumpWidget(_block(iljin: null));
      expect(find.byKey(DateBlock.iljinKey), findsNothing);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('11월 목요일'), findsOneWidget);
      expect(find.byType(SkeletonBone), findsNothing);
    });

    testWidgets('일진을 불러오는 중이면 그 자리에 글줄 뼈 하나(64)', (tester) async {
      await tester.pumpWidget(_block(iljin: null, iljinLoading: true));
      expect(find.byKey(DateBlock.iljinKey), findsNothing);
      final bone = find.byType(SkeletonBone);
      expect(bone, findsOneWidget);
      expect(tester.getSize(bone).width, DateBlock.iljinSkeletonWidth);
      expect(DateBlock.iljinSkeletonWidth, 64);
      expect(find.text('11월 목요일'), findsOneWidget);
    });

    testWidgets('스크린리더: 머리 하나로 "월 일 요일, 일진 독음"을 읽고 한자는 읽지 않습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_block());
      final node = tester.getSemantics(find.byType(DateBlock));
      expect(node.label, '11월 목요일 5, 계미일');
      expect(node.flagsCollection.isHeader, isTrue);
      expect(node.label, isNot(contains('癸')));
      handle.dispose();
    });
  });
}
