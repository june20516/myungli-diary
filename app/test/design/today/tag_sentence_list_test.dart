import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/tag_sentence_list.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

RenderedText _text(String value) =>
    RenderedText(segments: [Segment(text: value)]);

const _link = '천을귀인 태그가 붙은 일기 보기';
const _title = '이 기운에서 나온 오늘 문장';
const _empty = '오늘은 이 기운으로 정해진 문장이 없어요.';
const _fortune = '어려울 때 도와주는 사람이 곁에 오는 날이에요.';
const _question = '오늘 가장 오래 마음에 남은 장면은 무엇인가요?';

List<TagSentence> _items() => [
  TagSentence(kindLabel: '보조 문장', text: _text(_fortune)),
  TagSentence(kindLabel: '오늘의 질문', text: _text(_question)),
];

Widget _app({List<TagSentence>? items, VoidCallback? onLink}) => inputApp(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 360,
      child: TagSentenceList(
        title: _title,
        items: items ?? _items(),
        emptyText: _empty,
        diaryLinkLabel: _link,
        onDiaryLink: onLink ?? () {},
      ),
    ),
  ),
);

void main() {
  group('tag-sentence-list', () {
    testWidgets('머리 글자 아래 줄마다 이름 칸과 문장이 보입니다', (tester) async {
      await tester.pumpWidget(_app());
      final tokens = tester.element(find.byType(TagSentenceList)).tokens;
      final head = tester.widget<Text>(find.text(_title));
      expect(head.style?.fontSize, tokens.typography.labelMd.fontSize);
      expect(head.style?.color, tokens.colors.textSecondary);
      expect(find.text('보조 문장'), findsOneWidget);
      expect(find.text('오늘의 질문'), findsOneWidget);
      expect(find.text(_fortune, findRichText: true), findsOneWidget);
      expect(find.text(_question, findRichText: true), findsOneWidget);
      expect(find.text(_empty), findsNothing);
    });

    testWidgets('빈 목록이면 줄 없이 안내 한 줄만 둡니다', (tester) async {
      await tester.pumpWidget(_app(items: const []));
      final tokens = tester.element(find.byType(TagSentenceList)).tokens;
      expect(find.text(_title), findsOneWidget);
      final empty = tester.widget<Text>(find.byKey(TagSentenceList.emptyKey));
      expect(empty.data, _empty);
      expect(empty.style?.color, tokens.colors.textSecondary);
      expect(empty.style?.fontSize, tokens.typography.bodyUi.fontSize);
      expect(find.byKey(TagSentenceList.labelKey), findsNothing);
      expect(find.byType(ListDivider), findsNothing);
    });

    testWidgets('이름 칸은 폭 52이고 문장은 그 뒤 space.8에서 시작합니다', (tester) async {
      await tester.pumpWidget(_app());
      final label = tester.getRect(find.byKey(TagSentenceList.labelKey).first);
      expect(label.width, 52);
      final sentence = tester.getTopLeft(
        find.text(_fortune, findRichText: true),
      );
      expect(sentence.dx - label.left, 52 + 8);
    });

    testWidgets('이름 칸 글자는 caption.md text.secondary입니다', (tester) async {
      await tester.pumpWidget(_app());
      final tokens = tester.element(find.byType(TagSentenceList)).tokens;
      final label = tester.widget<Text>(find.text('보조 문장'));
      expect(label.style?.fontSize, tokens.typography.captionMd.fontSize);
      expect(label.style?.color, tokens.colors.textSecondary);
    });

    testWidgets('줄 사이에만 list.divider가 있고 첫 줄 위, 끝 줄 아래에는 없습니다', (tester) async {
      await tester.pumpWidget(_app());
      expect(find.byType(ListDivider), findsOneWidget);
      final divider = tester.getRect(find.byType(ListDivider));
      final first = tester.getRect(find.text(_fortune, findRichText: true));
      final second = tester.getRect(find.text(_question, findRichText: true));
      expect(divider.top, greaterThan(first.bottom));
      expect(divider.bottom, lessThan(second.top));
      // 한 줄이면 선이 없습니다.
      await tester.pumpWidget(_app(items: [_items().first]));
      expect(find.byType(ListDivider), findsNothing);
    });

    testWidgets('줄 위아래 안쪽 여백은 space.12입니다', (tester) async {
      await tester.pumpWidget(_app(items: [_items().first]));
      final head = tester.getBottomLeft(find.text(_title));
      final sentence = tester.getTopLeft(
        find.text(_fortune, findRichText: true),
      );
      // 머리 아래 8 + 줄 위 12.
      expect(sentence.dy - head.dy, 8 + 12);
    });

    testWidgets('이름이 넘치면 이름 칸 안에서 줄바꿈하고 문장 칸 폭은 줄지 않습니다', (tester) async {
      await tester.pumpWidget(_app());
      final tokens = tester.element(find.byType(TagSentenceList)).tokens;
      final longLabel = tester.getSize(find.text('오늘의 질문'));
      expect(
        longLabel.height,
        greaterThan(tokens.typography.captionMd.fontSize! * 1.5),
        reason: '오늘의 질문은 52 안에서 두 줄',
      );
      expect(longLabel.width, lessThanOrEqualTo(TagSentenceList.labelWidth));
      final fortune = tester.getRect(find.text(_fortune, findRichText: true));
      final question = tester.getRect(find.text(_question, findRichText: true));
      expect(question.left, fortune.left);
      expect(question.right, fortune.right);
    });

    testWidgets('문장 줄은 누를 수 없고 term 조각도 일반 글자입니다', (tester) async {
      final termText = RenderedText(
        segments: [
          Segment(text: '오늘은 '),
          Segment(text: '용신', term: 'yongsin'),
        ],
      );
      await tester.pumpWidget(
        _app(
          items: [TagSentence(kindLabel: '보조 문장', text: termText)],
        ),
      );
      final sentence = find.byType(SentenceBlock);
      expect(
        find.descendant(of: sentence, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: sentence, matching: find.byType(GestureDetector)),
        findsNothing,
      );
    });

    testWidgets('접근성: 머리는 header이고 줄은 이름 칸과 문장을 한 덩어리로 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      final head = tester.getSemantics(find.text(_title)).getSemanticsData();
      expect(head.flagsCollection.isHeader, isTrue);
      final row = tester.getSemantics(find.text('보조 문장')).getSemanticsData();
      expect(row.label, contains('보조 문장'));
      expect(row.label, contains(_fortune));
      handle.dispose();
    });

    testWidgets('글자 배율 2.0에서 넘치지 않습니다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_app());
      expect(tester.takeException(), isNull);
    });

    testWidgets('출구 링크는 문장이 없어도 늘 보이고 누르면 콜백이 불립니다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(items: const [], onLink: () => taps++));
      expect(find.text(_link), findsOneWidget);
      await tester.tap(find.byKey(TagSentenceList.diaryLinkKey));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets(
      '출구 링크: 위 간격 16, label.lg action.primary, 꺾쇠는 글자 뒤 space.2, 터치 44',
      (tester) async {
        await tester.pumpWidget(_app());
        final tokens = tester.element(find.byType(TagSentenceList)).tokens;
        final text = tester.widget<Text>(find.text(_link));
        expect(text.style?.fontSize, tokens.typography.labelLg.fontSize);
        expect(text.style?.color, tokens.colors.actionPrimary);
        final lastSentence = tester.getBottomLeft(
          find.text(_question, findRichText: true),
        );
        final link = tester.getRect(find.text(_link));
        // 마지막 줄 아래 안쪽 여백 12 + marginTop 16, 글자 상자 위까지.
        expect(link.top - lastSentence.dy, closeTo(12 + 16, 1));
        final icon = tester.getRect(find.byType(Icon));
        expect(icon.left - link.right, TagSentenceList.chevronGap);
        // 눌림 44는 레이아웃 안이라 글자 위아래 바깥 각각 동작하고, 44 밖은 동작하지 않습니다.
        var taps = 0;
        await tester.pumpWidget(_app(onLink: () => taps++));
        final target = tester.getRect(find.byKey(TagSentenceList.diaryLinkKey));
        expect(target.height, 44);
        final shown = tester.getRect(find.text(_link));
        await tester.tapAt(Offset(shown.center.dx, shown.top - 8));
        await tester.tapAt(Offset(shown.center.dx, shown.bottom + 8));
        expect(taps, 2);
        await tester.tapAt(Offset(shown.center.dx, target.top - 4));
        await tester.tapAt(Offset(shown.center.dx, target.bottom + 4));
        expect(taps, 2);
      },
    );

    testWidgets('출구 링크는 link로 읽히고 꺾쇠는 읽지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      final data = tester
          .getSemantics(find.byKey(TagSentenceList.diaryLinkKey))
          .getSemanticsData();
      expect(data.label, _link);
      expect(data.flagsCollection.isLink, isTrue);
      handle.dispose();
    });

    test('ComponentSpec은 변형 없이 empty, pressed 상태를 가집니다', () {
      expect(TagSentenceList.spec.id, 'tag-sentence-list');
      expect(TagSentenceList.spec.variants, isEmpty);
      expect(TagSentenceList.spec.states, {'empty', 'pressed'});
    });
  });
}
