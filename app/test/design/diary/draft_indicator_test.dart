import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

Widget _host(Widget child, {Locale locale = const Locale('ko')}) =>
    inputApp(Center(child: child), locale: locale);

void main() {
  group('draft-indicator 가운데 자리와 글자 수', () {
    testWidgets('length가 있으면 상태 글자 뒤 space.8에 글자 수를 그립니다', (tester) async {
      await tester.pumpWidget(
        _host(
          const DraftIndicator(
            state: DraftIndicatorState.local,
            label: '임시 저장됨',
            length: 1234,
          ),
        ),
      );
      expect(find.text('1234자'), findsOneWidget);
      final gap =
          tester.getTopLeft(find.text('1234자')).dx -
          tester.getTopRight(find.text('임시 저장됨')).dx;
      expect(gap, 8);
    });

    testWidgets('length가 없으면 글자 수를 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        _host(
          const DraftIndicator(state: DraftIndicatorState.saved, label: '저장됨'),
        ),
      );
      expect(find.textContaining('자'), findsNothing);
    });

    testWidgets('글자 수는 caption.md text.secondary 고정폭 숫자입니다', (tester) async {
      await tester.pumpWidget(
        _host(
          const DraftIndicator(
            state: DraftIndicatorState.local,
            label: '임시 저장됨',
            length: 7,
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('7자')).style!;
      final tokens = tester.element(find.text('7자')).tokens;
      expect(style.fontSize, tokens.typography.captionMd.fontSize);
      expect(style.color, tokens.colors.textSecondary);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('스크린리더는 상태 글자만 읽고 글자 수는 읽지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const DraftIndicator(
            state: DraftIndicatorState.local,
            label: '임시 저장됨',
            length: 99,
          ),
        ),
      );
      expect(find.bySemanticsLabel('임시 저장됨'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('99')), findsNothing);
      handle.dispose();
    });

    testWidgets('가운데 폭 152에서 상태 글자만 말줄임하고 글자 수는 지킵니다', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 152,
            child: DraftIndicator(
              state: DraftIndicatorState.local,
              label: 'Draft saved on this device only',
              length: 123,
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('123 chars'), findsOneWidget);
      final count = tester.getRect(find.textContaining('123'));
      final box = tester.getRect(find.byType(DraftIndicator));
      expect(count.right, lessThanOrEqualTo(box.right));
      final label = tester.widget<Text>(
        find.text('Draft saved on this device only'),
      );
      expect(label.overflow, TextOverflow.ellipsis);
      expect(label.maxLines, 1);
    });
  });
}
