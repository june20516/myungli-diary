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
  group('effectiveTextScale', () {
    testWidgets('상한이 없으면 기기 배율 그대로', (tester) async {
      await tester.pumpWidget(_at20(const Text('13')));
      expect(effectiveTextScale(tester, find.byType(Text)), closeTo(20, 0.001));
    });

    testWidgets('MediaQuery로 건 상한', (tester) async {
      await tester.pumpWidget(
        _at20(
          Builder(
            builder: (context) => MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: const Text('13'),
            ),
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

    testWidgets('상한 없는 RichText는 상한이 없다고 보지 않고 실제 값을 잽니다', (tester) async {
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
