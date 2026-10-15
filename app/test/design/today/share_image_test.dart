import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

const String _sentenceText =
    '오늘은 기운의 흐름이 나를 도와주는 날이에요. 먼저 연락해 보세요. 좋은 소식이 올 거예요!';

RenderedText _text(String value) =>
    RenderedText(segments: [Segment(text: value)]);

List<LuckyItem> _items() => [
  LuckyItem(
    variant: LuckyCardVariant.color,
    name: '행운 색',
    value: '파랑',
    explain: _text('물의 기운이 마음을 가라앉혀요.'),
    swatch: const Color(0xFF3B6FB6),
  ),
  LuckyItem(
    variant: LuckyCardVariant.direction,
    name: '행운 방향',
    value: '동쪽',
    explain: _text('동쪽에서 좋은 기운이 들어와요.'),
  ),
  LuckyItem(
    variant: LuckyCardVariant.number,
    name: '행운 숫자',
    value: '3',
    explain: _text('3이 흐름을 열어 줘요.'),
  ),
  LuckyItem(
    variant: LuckyCardVariant.time,
    name: '집중 시간',
    value: '오후 3시',
    explain: _text('오후 3시에 집중이 잘 돼요.'),
  ),
];

ShareImage _image(
  ShareImageVariant variant, {
  String sentence = _sentenceText,
  bool withReason = true,
}) => ShareImage(
  variant: variant,
  date: '10월 15일 목요일',
  dayKind: DayKind.yongsinDay,
  dayKindLabel: '좋은 날',
  sentence: _text(sentence),
  items: _items(),
  footer: '명리일기',
  reason: withReason ? _text('기운의 흐름이 나를 도와주는 날이라서요.') : null,
);

/// 논리 크기 그대로 그립니다(화면 폭이 모자라면 위로 자라게 둡니다).
Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    inputApp(
      Center(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
      brightness: brightness,
    );

Future<void> _bigScreen(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(800, 1000);
  addTearDown(tester.view.reset);
}

int _chipCount(WidgetTester tester) => find.byType(LuckyChip).evaluate().length;

void main() {
  group('firstSentence', () {
    test('첫 마침표까지 자릅니다', () {
      expect(firstSentence('오늘은 좋아요. 그리고'), '오늘은 좋아요.');
    });

    test('물음표·느낌표·일본어 마침표도 문장 끝입니다', () {
      expect(firstSentence('괜찮을까요? 네'), '괜찮을까요?');
      expect(firstSentence('좋아요! 가요'), '좋아요!');
      expect(firstSentence('今日は良い日です。さあ'), '今日は良い日です。');
    });

    test('끝 문장부호가 없으면 전체입니다', () {
      expect(firstSentence('오늘은 좋아요'), '오늘은 좋아요');
    });

    test('숫자 사이의 마침표는 소수점이라 자르지 않습니다', () {
      expect(firstSentence('집중이 2.5배 잘 돼요. 그리고'), '집중이 2.5배 잘 돼요.');
      expect(firstSentence('3. 좋아요'), '3.');
    });

    test('문장부호 바로 뒤의 닫는 따옴표·괄호는 문장에 포함합니다', () {
      expect(firstSentence('“좋아요.” 그리고'), '“좋아요.”');
      expect(firstSentence('좋아요.) 그리고'), '좋아요.)');
      expect(firstSentence('「今日は良い日です。」さあ'), '「今日は良い日です。」');
      expect(firstSentence("'괜찮아요?' 네"), "'괜찮아요?'");
    });

    test('앞뒤 공백은 다듬습니다', () {
      expect(firstSentence('  좋아요.  '), '좋아요.');
    });
  });

  group('크기', () {
    test('논리 크기는 변형별 비율이고 폭 360 x 3 = 1080입니다', () {
      expect(
        ShareImage.logicalSize(ShareImageVariant.story),
        const Size(360, 640),
      );
      expect(
        ShareImage.logicalSize(ShareImageVariant.feed),
        const Size(360, 450),
      );
      expect(
        ShareImage.logicalSize(ShareImageVariant.square),
        const Size(360, 360),
      );
    });

    test('변형 id가 명세와 같습니다', () {
      expect(ShareImageVariant.values.map((v) => v.name), [
        'story',
        'feed',
        'square',
      ]);
    });

    for (final variant in ShareImageVariant.values) {
      testWidgets('${variant.name}: 화면 폭·글자 배율과 상관없이 논리 크기로 그립니다', (
        tester,
      ) async {
        await _bigScreen(tester);
        await tester.pumpWidget(
          _app(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(300, 500),
                textScaler: TextScaler.linear(2),
              ),
              child: _image(variant),
            ),
          ),
        );
        expect(
          tester.getSize(find.byKey(ShareImage.canvasKey)),
          ShareImage.logicalSize(variant),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('아주 긴 문장도 넘치지 않고 논리 크기를 지킵니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(
        _app(_image(ShareImageVariant.story, sentence: '오늘은 좋은 날이에요. ' * 40)),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(ShareImage.canvasKey)),
        ShareImage.logicalSize(ShareImageVariant.story),
      );
    });
  });

  group('라이트 고정(V5)', () {
    testWidgets('기기가 다크여도 라이트 그라데이션·글자색으로 그립니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(
        _app(_image(ShareImageVariant.story), brightness: Brightness.dark),
      );
      final canvas = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(ShareImage.canvasKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = canvas.decoration as BoxDecoration;
      expect(decoration.gradient, lightGradients.today);

      final sentence = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(ShareImage.sentenceKey),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(sentence.text.style?.color, lightColors.textPrimary);
      // 안쪽 위젯이 읽는 테마도 라이트입니다.
      final theme = Theme.of(
        tester.element(find.byKey(ShareImage.sentenceKey)),
      );
      expect(theme.brightness, Brightness.light);
      expect(
        tester.element(find.byKey(ShareImage.sentenceKey)).tokens.colors.bgBase,
        lightColors.bgBase,
      );
    });

    testWidgets('라이트 기기와 다크 기기의 글자색이 같습니다', (tester) async {
      await _bigScreen(tester);
      Color? sentenceColor() => tester
          .widget<RichText>(
            find
                .descendant(
                  of: find.byKey(ShareImage.sentenceKey),
                  matching: find.byType(RichText),
                )
                .first,
          )
          .text
          .style
          ?.color;
      await tester.pumpWidget(_app(_image(ShareImageVariant.feed)));
      final light = sentenceColor();
      await tester.pumpWidget(
        _app(_image(ShareImageVariant.feed), brightness: Brightness.dark),
      );
      expect(sentenceColor(), light);
    });
  });

  group('변형별 구성', () {
    testWidgets('story: 이유가 보이고 칩 4개, 문장은 전체입니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(_app(_image(ShareImageVariant.story)));
      expect(find.byKey(ShareImage.reasonKey), findsOneWidget);
      expect(find.textContaining('도와주는 날이라서요'), findsOneWidget);
      expect(_chipCount(tester), 4);
      expect(find.textContaining('좋은 소식이 올 거예요!'), findsOneWidget);
      expect(find.text('좋은 날'), findsOneWidget);
      expect(find.text('10월 15일 목요일'), findsOneWidget);
      expect(find.text('명리일기'), findsOneWidget);
    });

    testWidgets('story: reason이 null이면 이유 줄이 없습니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(
        _app(_image(ShareImageVariant.story, withReason: false)),
      );
      expect(find.byKey(ShareImage.reasonKey), findsNothing);
    });

    testWidgets('feed: 이유가 없고 문장 두 줄, 칩 3개(색·방향·숫자)입니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(_app(_image(ShareImageVariant.feed)));
      expect(find.byKey(ShareImage.reasonKey), findsNothing);
      expect(_chipCount(tester), 3);
      for (final variant in [
        LuckyCardVariant.color,
        LuckyCardVariant.direction,
        LuckyCardVariant.number,
      ]) {
        expect(
          find.byWidgetPredicate(
            (w) => w is LuckyChip && w.item.variant == variant,
          ),
          findsOneWidget,
        );
      }
      final text = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(ShareImage.sentenceKey),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('square: 첫 문장만 보이고 칩 3개, 이유 없음입니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(_app(_image(ShareImageVariant.square)));
      expect(find.byKey(ShareImage.reasonKey), findsNothing);
      expect(_chipCount(tester), 3);
      final text = tester
          .widget<RichText>(
            find
                .descendant(
                  of: find.byKey(ShareImage.sentenceKey),
                  matching: find.byType(RichText),
                )
                .first,
          )
          .text
          .toPlainText();
      expect(text, '오늘은 기운의 흐름이 나를 도와주는 날이에요.');
    });

    testWidgets('칩은 표시 전용이고 판정 여유를 두지 않습니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(_app(_image(ShareImageVariant.story)));
      expect(
        find.byWidgetPredicate((w) => w is LuckyChip && w.onTap != null),
        findsNothing,
      );
      expect(find.byType(LuckyCardRow), findsNothing);
    });

    testWidgets('배지는 날의 성격 변형을 따릅니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(_app(_image(ShareImageVariant.story)));
      final badge = tester.widget<DayCharacterBadge>(
        find.byType(DayCharacterBadge),
      );
      expect(badge.variant, DayCharacterVariant.good);
      expect(badge.label, '좋은 날');
    });

    testWidgets('로고를 그립니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(_app(_image(ShareImageVariant.story)));
      expect(find.byKey(ShareImage.logoKey), findsOneWidget);
    });
  });

  group('접근성', () {
    testWidgets('이미지 하나로 읽고 라벨은 미리보기, altText는 문장 전체입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _bigScreen(tester);
      await tester.pumpWidget(_app(_image(ShareImageVariant.square)));
      final node = tester.getSemantics(find.byKey(ShareImage.semanticsKey));
      final data = node.getSemanticsData();
      expect(data.label, '오늘 문장 이미지 미리보기'); // ARB shareImageSemantics(ko)
      expect(data.value, _sentenceText);
      expect(data.flagsCollection.isImage, isTrue);
      // 화면 글자·칩은 같은 말을 다시 읽지 않습니다.
      expect(find.bySemanticsLabel('행운 색, 파랑'), findsNothing);
      handle.dispose();
    });

    testWidgets('라벨을 주지 않으면 언어에 맞는 ARB 문구를 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _bigScreen(tester);
      await tester.pumpWidget(
        inputApp(
          Center(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: _image(ShareImageVariant.feed),
            ),
          ),
          locale: const Locale('ja'),
        ),
      );
      final data = tester
          .getSemantics(find.byKey(ShareImage.semanticsKey))
          .getSemanticsData();
      expect(data.label, '今日の一文の画像プレビュー');
      handle.dispose();
    });

    testWidgets('semanticLabel로 다른 언어 라벨을 줄 수 있습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _bigScreen(tester);
      await tester.pumpWidget(
        _app(
          ShareImage(
            variant: ShareImageVariant.feed,
            date: '10月15日',
            dayKind: DayKind.ordinaryDay,
            dayKindLabel: '普通の日',
            sentence: _text('今日は穏やかな日です。'),
            items: _items(),
            footer: '命理日記',
            semanticLabel: '今日の一文の画像プレビュー',
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byKey(ShareImage.semanticsKey))
          .getSemanticsData();
      expect(data.label, '今日の一文の画像プレビュー');
      expect(data.value, '今日は穏やかな日です。');
      handle.dispose();
    });
  });

  group('ShareImagePreview', () {
    Widget preview(ShareImageVariant variant, {bool reduceMotion = false}) =>
        MotionPrefsScope(
          prefs: MotionPrefs(
            reduceMotion: reduceMotion,
            reduceTransparency: false,
            lowEnd: false,
          ),
          child: inputApp(
            Center(
              child: SizedBox(
                width: 180,
                child: ShareImagePreview(image: _image(variant)),
              ),
            ),
          ),
        );

    testWidgets('주어진 폭에 맞춰 같은 위젯을 줄여 보입니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(preview(ShareImageVariant.story));
      expect(
        tester.getSize(find.byKey(ShareImagePreview.frameKey)),
        const Size(180, 320),
      );
      await tester.pumpWidget(preview(ShareImageVariant.square));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(ShareImagePreview.frameKey)),
        const Size(180, 180),
      );
    });

    testWidgets('처음 나타날 때는 전환 없이 보입니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(preview(ShareImageVariant.story));
      expect(_previewOpacity(tester), 1);
    });

    testWidgets('비율이 바뀌면 appear.seep으로 나타납니다(흐림 포함)', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(preview(ShareImageVariant.story));
      await tester.pumpWidget(preview(ShareImageVariant.feed));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _previewOpacity(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      expect(
        find.descendant(
          of: find.byKey(ShareImagePreview.frameKey),
          matching: find.byType(ImageFiltered),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(_previewOpacity(tester), 1);
    });

    testWidgets('동작 줄이기면 흐림 없이 투명도만 바뀝니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(
        preview(ShareImageVariant.story, reduceMotion: true),
      );
      await tester.pumpWidget(
        preview(ShareImageVariant.feed, reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_previewOpacity(tester), lessThan(1));
      expect(
        find.descendant(
          of: find.byKey(ShareImagePreview.frameKey),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
    });

    testWidgets('같은 비율로 내용만 바뀌면 전환하지 않습니다', (tester) async {
      await _bigScreen(tester);
      await tester.pumpWidget(preview(ShareImageVariant.feed));
      await tester.pumpWidget(preview(ShareImageVariant.feed));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_previewOpacity(tester), 1);
    });
  });
}

double _previewOpacity(WidgetTester tester) {
  final opacities = find.descendant(
    of: find.byKey(ShareImagePreview.frameKey),
    matching: find.byType(Opacity),
  );
  if (opacities.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(opacities.first).opacity;
}
