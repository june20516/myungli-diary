import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

void main() {
  group('share-button', () {
    testWidgets('soft는 면 높이 36이고 눌림 영역은 44입니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: ShareButton(
              variant: ShareButtonVariant.soft,
              label: '공유',
              onPressed: () => pressed++,
            ),
          ),
        ),
      );
      final face = find.byKey(ShareButton.faceKey);
      expect(tester.getSize(face).height, 36);

      // 면 위 끝에서 3px 밖(44 안)을 눌러도 동작합니다.
      await tester.tapAt(tester.getTopLeft(face) + const Offset(20, -3));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      // 44 밖은 닿지 않습니다.
      await tester.tapAt(tester.getTopLeft(face) + const Offset(20, -6));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('soft는 status 색 바탕에 글자가 보입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: ShareButton(
              variant: ShareButtonVariant.soft,
              label: '공유',
              onPressed: () {},
            ),
          ),
        ),
      );
      final colors = tester.element(find.byType(ShareButton)).tokens.colors;
      final box = tester.widget<DecoratedBox>(find.byKey(ShareButton.faceKey));
      expect((box.decoration as BoxDecoration).color, colors.statusBg);
      expect(find.text('공유'), findsOneWidget);
    });

    testWidgets('icon은 글자 없이 44x44 눌림 영역이고 라벨은 스크린리더용입니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        inputApp(
          Center(
            child: ShareButton(
              variant: ShareButtonVariant.icon,
              label: '공유',
              onPressed: () => pressed++,
            ),
          ),
        ),
      );
      expect(find.text('공유'), findsNothing);
      final target = tester.getSize(find.byKey(ShareButton.faceKey));
      expect(target, const Size.square(44));
      expect(find.bySemanticsLabel('공유'), findsOneWidget);
      await tester.tap(find.byKey(ShareButton.faceKey));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });
  });
}
