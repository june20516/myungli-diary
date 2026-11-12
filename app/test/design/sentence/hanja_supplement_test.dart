import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';

import '../input/input_harness.dart';

/// 대체 글꼴 family(토큰 1.9.0 `font.family.*` fallback, D124).
const _supplement = 'Myungli Hanja Supplement';

/// 罡이 든 글자 조각마다, 그 조각까지 내려가며 합친 글꼴 fallback.
List<List<String>> _fallbacksOf(WidgetTester tester) {
  final result = <List<String>>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    void visit(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        if (span.text?.contains('罡') ?? false) {
          result.add(style?.fontFamilyFallback ?? const []);
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, style);
        }
      }
    }

    visit(rich.text, null);
  }
  return result;
}

/// 열린 근거 시트의 원전 하나([lines]는 원고의 뜻, 원문, 출처 줄).
Widget _evidence(List<String> lines) => SizedBox(
  height: 400,
  child: EvidenceSheetBody(
    state: DepthLinkState.unlocked,
    title: '괴강',
    source: [
      RenderedText(segments: [Segment(text: lines.join('\n'))]),
    ],
    animated: false,
  ),
);

void main() {
  testWidgets('ja: 괴강 魁罡은 term-token 칩과 근거 원전 출처에서 대체 글꼴을 거칩니다', (
    tester,
  ) async {
    await tester.pumpWidget(
      inputApp(
        locale: const Locale('ja'),
        SingleChildScrollView(
          child: Column(
            children: [
              TermToken(
                label: '魁罡',
                variant: TermTokenVariant.inline,
                onTap: () {},
              ),
              TermToken(
                label: '魁罡',
                variant: TermTokenVariant.label,
                onTap: () {},
              ),
              // writing ja 원고 `source.sammyeong-tonghoe/shinsal#goegang`.
              _evidence(const [
                'この格には庚辰、壬辰、戊戌、庚戌の四つの日があるという意味です。',
                '此格有四日庚辰壬辰戊戌庚戌',
                '三命通会「魁罡」',
              ]),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fallbacks = _fallbacksOf(tester);
    // 칩 둘과 원전 출처 줄 하나.
    expect(fallbacks, hasLength(3));
    for (final fallback in fallbacks) {
      expect(fallback, contains(_supplement));
    }
  });

  testWidgets('en: 원전 출처 줄의 魁罡도 한자 글꼴 다음 대체 글꼴을 거칩니다(문장 글꼴이 Pretendard)', (
    tester,
  ) async {
    await tester.pumpWidget(
      inputApp(
        locale: const Locale('en'),
        // writing en 원고 `source.sammyeong-tonghoe/shinsal#goegang`.
        _evidence(const [
          'This pattern has four days: Gyeongjin, Imjin, Musul and Gyeongsul.',
          '此格有四日庚辰壬辰戊戌庚戌',
          'Sammyeong Tonghoe, 魁罡',
        ]),
      ),
    );
    await tester.pumpAndSettle();
    final fallback = _fallbacksOf(tester).single;
    expect(fallback, containsAllInOrder(['Pretendard JP', _supplement]));
  });
}
