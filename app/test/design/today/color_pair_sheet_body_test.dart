import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/today/color_pair_sheet_body.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/elements/ohaeng_swatch.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../../support/depth_link_finders.dart';
import '../input/input_harness.dart';

RenderedText _text(String value) =>
    RenderedText(segments: [Segment(text: value)]);

void main() {
  final evidence = <String>[];

  Widget body({bool withEvidence = true}) => inputApp(
    SizedBox(
      width: 360,
      child: ColorPairSheetBody(
        title: '행운 색',
        intro: '오늘은 추천 색이 두 개예요',
        sections: [
          ColorPairSection(
            element: FiveElement.water,
            name: '검정',
            body: _text('내 사주의 균형으로 보면 검정이 잘 맞아요.'),
            bodySlotId: SlotIds.todayLuckyColorBody,
            onEvidence: withEvidence ? () => evidence.add('검정') : null,
          ),
          ColorPairSection(
            element: FiveElement.earth,
            name: '노랑',
            body: _text('원전의 해석에 따르면 오늘은 노랑도 어울려요.'),
            bodySlotId: SlotIds.todayLuckyColorSecondBody,
            onEvidence: withEvidence ? () => evidence.add('노랑') : null,
          ),
        ],
      ),
    ),
  );

  setUp(evidence.clear);

  Finder section(int index) => find.byKey(ColorPairSheetBody.sectionKey(index));

  testWidgets('제목, 한 줄 안내, 첫째 색, 구분선, 둘째 색 순서입니다', (tester) async {
    await tester.pumpWidget(body());
    final title = tester.getRect(find.text('행운 색'));
    final intro = tester.getRect(
      find.byKey(const ValueKey(SlotIds.todayLuckyColorPairIntro)),
    );
    final first = tester.getRect(section(0));
    final divider = tester.getRect(find.byKey(ColorPairSheetBody.dividerKey));
    final second = tester.getRect(section(1));
    expect(intro.top - title.bottom, ExplainSheetBody.titleGap);
    expect(first.top - intro.bottom, 12);
    expect(divider.top - first.bottom, 16);
    expect(second.top - divider.bottom, 16);
    expect(find.byType(ListDivider), findsOneWidget);
    // 구역에 좌우 여백이 없어 구분선을 들이지 않습니다(A135 ④, design #1072 답 전 임시값).
    expect(divider.left, first.left);
    expect(divider.right, first.right);
    expect(
      find.descendant(
        of: section(0),
        matching: find.byKey(const ValueKey(SlotIds.todayLuckyColorBody)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: section(1),
        matching: find.byKey(const ValueKey(SlotIds.todayLuckyColorSecondBody)),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    '한 줄 안내는 caption.lg text.secondary, 색 이름은 label.lg text.primary입니다',
    (tester) async {
      await tester.pumpWidget(body());
      final tokens = tester.element(section(0)).tokens;
      final intro = tester.widget<Text>(
        find.byKey(const ValueKey(SlotIds.todayLuckyColorPairIntro)),
      );
      expect(intro.style?.fontSize, tokens.typography.captionLg.fontSize);
      expect(intro.style?.color, tokens.colors.textSecondary);
      final name = tester.widget<Text>(find.text('노랑'));
      expect(name.style?.fontSize, tokens.typography.labelLg.fontSize);
      expect(name.style?.fontWeight, tokens.typography.labelLg.fontWeight);
      expect(name.style?.color, tokens.colors.textPrimary);
    },
  );

  testWidgets('구역 머리는 견본 14와 이름 사이 4, 머리 아래 8에 풀이 문장입니다', (tester) async {
    await tester.pumpWidget(body());
    final swatch = find.descendant(
      of: section(0),
      matching: find.byType(OhaengSwatch),
    );
    expect(tester.getSize(swatch), const Size(14, 14));
    final name = tester.getRect(find.text('검정'));
    expect(name.left - tester.getRect(swatch).right, 4);
    final sentence = tester.getRect(
      find.byKey(const ValueKey(SlotIds.todayLuckyColorBody)),
    );
    expect(sentence.top - name.bottom, 8);
  });

  testWidgets('기준 이름 부제목이 없고 글자는 제목, 안내, 이름, 문장뿐입니다', (tester) async {
    await tester.pumpWidget(body(withEvidence: false));
    for (final word in ['내 균형', '원전 기준', '균형 기준']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });

  testWidgets('색마다 풀이 아래 그 색의 근거 진입점이 있고 그 색 이름으로 읽힙니다', (tester) async {
    await tester.pumpWidget(body());
    for (final (index, name) in [(0, '검정'), (1, '노랑')]) {
      final link = depthLinkTarget(of: section(index));
      expect(link, findsOneWidget, reason: name);
      expect(
        tester
            .widget<DepthLink>(
              find.descendant(
                of: section(index),
                matching: find.byType(DepthLink),
              ),
            )
            .subject,
        name,
      );
      final sentence = tester.getRect(
        find.descendant(
          of: section(index),
          matching: find.byKey(
            ValueKey(
              index == 0
                  ? SlotIds.todayLuckyColorBody
                  : SlotIds.todayLuckyColorSecondBody,
            ),
          ),
        ),
      );
      expect(tester.getTopLeft(link).dy, greaterThan(sentence.top));
      await tester.tap(link);
      await tester.pump();
    }
    expect(evidence, ['검정', '노랑']);
  });

  testWidgets('근거를 열 수 없으면 진입점을 그리지 않습니다', (tester) async {
    await tester.pumpWidget(body(withEvidence: false));
    expect(find.byType(DepthLink), findsNothing);
  });
}
