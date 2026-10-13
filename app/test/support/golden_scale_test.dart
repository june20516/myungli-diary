import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden.dart';

Widget _at20(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2)),
    child: child,
  ),
);

void main() {
  testWidgets('ensureGoldenFonts 뒤에는 앱 글꼴이 Ahem과 다른 폭으로 그려집니다', (tester) async {
    double widthOf(String family) {
      final painter = TextPainter(
        text: TextSpan(
          text: '명리일기 Hello 123',
          style: TextStyle(fontFamily: family),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    final fallback = widthOf('NoSuchFamily');
    await tester.runAsync(ensureGoldenFonts);
    // 두 번째 호출은 같은 Future를 돌려줘 다시 올리지 않습니다.
    expect(identical(ensureGoldenFonts(), ensureGoldenFonts()), isTrue);
    for (final family in ['Gowun Dodum', 'Pretendard']) {
      expect(widthOf(family), isNot(fallback), reason: family);
    }
  });

  group('effectiveTextScale', () {
    testWidgets('상한이 없으면 기기 배율 그대로', (tester) async {
      await tester.pumpWidget(_at20(const Text('13')));
      expect(effectiveTextScale(tester, find.byType(Text)), closeTo(20, 0.001));
    });

    testWidgets('MediaQuery로 건 상한', (tester) async {
      await tester.pumpWidget(
        _at20(
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: const Text('13'),
          ),
        ),
      );
      expect(effectiveTextScale(tester, find.byType(Text)), closeTo(13, 0.001));
    });

    testWidgets('Text(textScaler:)로 건 상한', (tester) async {
      await tester.pumpWidget(
        _at20(
          Builder(
            builder: (context) => Text(
              '13',
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3),
            ),
          ),
        ),
      );
      expect(effectiveTextScale(tester, find.byType(Text)), closeTo(13, 0.001));
    });

    testWidgets('RichText 대상(textScaler 직접)', (tester) async {
      await tester.pumpWidget(
        _at20(
          Builder(
            builder: (context) => RichText(
              text: const TextSpan(text: '13'),
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3),
            ),
          ),
        ),
      );
      expect(
        effectiveTextScale(tester, find.byType(RichText).first),
        closeTo(13, 0.001),
      );
    });

    testWidgets(
      'MediaQuery clamp 1.3 + Text(textScaler: linear(2))는 20(상한 누락)',
      (tester) async {
        await tester.pumpWidget(
          _at20(
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: const Text('13', textScaler: TextScaler.linear(2)),
            ),
          ),
        );
        expect(
          effectiveTextScale(tester, find.byType(Text)),
          closeTo(20, 0.001),
        );
      },
    );

    testWidgets('자체 scaler 없는 RichText는 MediaQuery를 무시해 10(noScaling)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _at20(
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: RichText(text: const TextSpan(text: '13')),
          ),
        ),
      );
      expect(
        effectiveTextScale(tester, find.byType(RichText).first),
        closeTo(10, 0.001),
      );
    });

    testWidgets('RichText에 MediaQuery 값을 직접 넘기면 그 값(20)', (tester) async {
      await tester.pumpWidget(
        _at20(
          Builder(
            builder: (context) => RichText(
              text: const TextSpan(text: '13'),
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
        ),
      );
      expect(
        effectiveTextScale(tester, find.byType(RichText).first),
        closeTo(20, 0.001),
      );
    });

    testWidgets('글자가 없는 대상은 명확히 실패합니다', (tester) async {
      await tester.pumpWidget(_at20(const Icon(Icons.add)));
      expect(
        () => effectiveTextScale(tester, find.byType(Text)),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            contains('fixedCellTarget'),
          ),
        ),
      );
    });
  });
}
