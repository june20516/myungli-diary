import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../../support/fonts.dart';
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

    // 일기 본문 상한(계약 10000자)을 그대로 씁니다.
    const maxLength = DiaryEditor.defaultMaxLength;
    // 고정부: 아이콘 16 + 간격 4 + 글자 수 앞 간격 8.
    const fixedWidth = 16.0 + 4 + 8;
    // app-bar edit 가운데 폭: 최소 지원 화면 폭 320 - 좌우 여백 16씩 - 양쪽 88.
    const centerWidth = 320.0 - 16 * 2 - 88 * 2;
    const longLabel = 'Draft saved on this device only, not yet sent';

    for (final locale in ['ko', 'en', 'ja']) {
      testWidgets('$locale: 상한 글자 수는 가운데 폭에 들어가고 좁으면 상태 글자만 말줄임합니다', (
        tester,
      ) async {
        await loadBundledFonts();
        Widget indicator(double width) => _host(
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: width,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: DraftIndicator(
                  state: DraftIndicatorState.local,
                  label: longLabel,
                  length: maxLength,
                ),
              ),
            ),
          ),
          locale: Locale(locale),
        );
        final count = find.textContaining('10000');
        final label = find.text(longLabel);

        // 넉넉한 폭에서 자연 폭을 잽니다.
        await tester.pumpWidget(indicator(2000));
        final countWidth = tester.getSize(count).width;
        final labelNatural = tester.getSize(label).width;

        // 고정부 + 글자 수가 실제 가운데 폭에 들어갑니다.
        expect(fixedWidth + countWidth, lessThanOrEqualTo(centerWidth));

        // 고정부 + 글자 수 + 상태 글자 일부 폭으로 좁힙니다.
        const labelPart = 24.0;
        await tester.pumpWidget(indicator(fixedWidth + countWidth + labelPart));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(label).width, lessThan(labelNatural));
        expect(tester.getSize(label).width, lessThanOrEqualTo(labelPart));
        expect(tester.getSize(count).width, countWidth);
        final text = tester.widget<Text>(label);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
      });
    }
  });
}
