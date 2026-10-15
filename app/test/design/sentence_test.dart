import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/text/keep_all.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../support/golden.dart' show ensureGoldenFonts;

Widget _app(
  Widget home, {
  Locale locale = const Locale('ko'),
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: brightness, locale: locale),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: home),
  ),
);

RenderedText _text(List<Segment> segments) => RenderedText(segments: segments);

final RenderedText _siksin = _text([
  Segment(text: '오늘은 '),
  Segment(text: '식신', term: 'TenGod.SIKSIN'),
  Segment(text: '의 날이에요.'),
]);

const TextStyle _style = TextStyle(fontSize: 15, height: 1.6);

List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

SemanticsData _semantics(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

SemanticsNode _rootSemantics(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;

/// Text.rich가 감싼 바깥 span 안, 문장 span의 스타일.
TextStyle _childStyle(RichText richText) =>
    (richText.text as TextSpan).children!.whereType<TextSpan>().first.style!;

/// 화면에 그려진 모든 글자(Text.rich 안 글자 포함)를 이어 붙입니다.
String _allText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText(includePlaceholders: false))
    .join('|');

void main() {
  group('RenderedTextView', () {
    testWidgets('조각이 한 문단으로 이어지고 용어 조각만 눌립니다', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _siksin,
            style: _style,
            onTerm: tapped.add,
          ),
        ),
      );
      // 조각마다 따로 줄을 바꾸지 않고 Text.rich 하나로 그립니다.
      expect(
        find.descendant(
          of: find.byType(RenderedTextView),
          matching: find.byType(RichText),
        ),
        findsNWidgets(3),
        reason: '문장 Text.rich 하나 + 칩 글자 + 붙은 조사(조각마다 따로 그리지 않음)',
      );
      expect(_allText(tester), contains('오늘은 '));
      expect(find.byType(TermToken), findsOneWidget);

      final paragraph = find
          .descendant(
            of: find.byType(RenderedTextView),
            matching: find.byType(RichText),
          )
          .first;
      await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(4, 4));
      expect(tapped, isEmpty, reason: '일반 글자는 눌려도 아무 일이 없음');

      await tester.tap(find.text('식신'));
      expect(tapped, ['TenGod.SIKSIN']);
    });

    testWidgets('onTerm이 없으면 용어도 일반 글자입니다', (tester) async {
      await tester.pumpWidget(
        _app(RenderedTextView(text: _siksin, style: _style)),
      );
      expect(find.byType(TermToken), findsNothing);
      expect(_allText(tester), '오늘은 식신의 날이에요.');
    });

    testWidgets('빈 segments는 아무것도 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _text([]),
            style: _style,
            onTerm: (_) {},
          ),
        ),
      );
      expect(find.byType(RichText), findsNothing);
      expect(tester.getSize(find.byType(RenderedTextView)), Size.zero);
    });

    testWidgets('한국어는 용어 뒤 조사까지 한 덩어리로 묶습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _siksin,
            style: _style,
            onTerm: (_) {},
          ),
        ),
      );
      // 칩 옆에 붙은 "의"는 칩과 같은 덩어리(위젯)에 있고, 바깥 문단에는 남지 않습니다.
      final outer = tester
          .widget<RichText>(
            find
                .descendant(
                  of: find.byType(RenderedTextView),
                  matching: find.byType(RichText),
                )
                .first,
          )
          .text
          .toPlainText(includePlaceholders: false);
      expect(outer, '오늘은  날이에요.');
      expect(find.text('의'), findsOneWidget);
    });

    testWidgets('일본어는 조사를 묶지 않고 용어만 한 덩어리로 둡니다', (tester) async {
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _text([
              Segment(text: '今日は'),
              Segment(text: '食神', term: 'TenGod.SIKSIN'),
              Segment(text: 'の日です。'),
            ]),
            style: _style,
            onTerm: (_) {},
          ),
          locale: const Locale('ja'),
        ),
      );
      expect(find.text('の'), findsNothing);
      expect(_allText(tester), contains('の日です。'));
      expect(find.text('食神'), findsOneWidget);
    });

    testWidgets('trailing은 문장 끝에 붙습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            text: _siksin,
            style: _style,
            trailing: const Text('근거 보기 ›'),
          ),
        ),
      );
      expect(find.text('근거 보기 ›'), findsOneWidget);
    });

    testWidgets('용어 라벨은 "용어 + 뜻 보기"로 읽고 term 값은 읽지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _siksin,
            style: _style,
            onTerm: (_) {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('식신의 뜻 보기'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('TenGod')), findsNothing);
      handle.dispose();
    });
  });

  group('TermToken', () {
    testWidgets('바탕·글자색은 term 요소이고 굵게 하지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          TermToken(
            label: '식신',
            variant: TermTokenVariant.inline,
            onTap: () {},
            textStyle: _style,
          ),
        ),
      );
      final context = tester.element(find.byType(TermToken));
      final colors = context.tokens.colors;
      final text = tester.widget<Text>(find.text('식신'));
      expect(text.style!.color, colors.termFg);
      expect(text.style!.fontWeight, isNot(FontWeight.bold));
      final box = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(TermToken),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == colors.termBg);
      expect(box.borderRadius, BorderRadius.circular(Radii.xs));
    });

    testWidgets('label 변형은 caption.md 글자입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          TermToken(label: '정관', variant: TermTokenVariant.label, onTap: () {}),
        ),
      );
      final context = tester.element(find.byType(TermToken));
      final text = tester.widget<Text>(find.text('정관'));
      expect(
        text.style!.fontSize,
        context.tokens.typography.captionMd.fontSize,
      );
    });

    testWidgets('글자 높이가 낮아도 위아래 44px까지 눌립니다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Padding(
            padding: const EdgeInsets.all(40),
            child: TermToken(
              label: '식신',
              variant: TermTokenVariant.inline,
              onTap: () => taps++,
              textStyle: _style,
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TermToken));
      expect(rect.height, lessThan(44));
      final slop = (44 - rect.height) / 2;
      await tester.tapAt(Offset(rect.center.dx, rect.top - slop + 1));
      await tester.tapAt(Offset(rect.center.dx, rect.bottom + slop - 1));
      expect(taps, 2);
      await tester.tapAt(Offset(rect.center.dx, rect.top - slop - 2));
      expect(taps, 2, reason: '44px 밖은 눌리지 않음');
    });

    testWidgets('버튼으로 읽고 라벨에 "뜻 보기"가 붙습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          TermToken(
            label: '식신',
            variant: TermTokenVariant.inline,
            onTap: () {},
          ),
        ),
      );
      final data = _semantics(tester, find.bySemanticsLabel('식신 뜻 보기'));
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('TermToken 붙은 글자와 좁은 폭', () {
    Widget token(double width) => SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.topLeft,
        child: TermToken(
          label: '천을귀인',
          variant: TermTokenVariant.inline,
          onTap: () {},
          textStyle: _style,
          after: '이',
        ),
      ),
    );

    for (final scale in [2.0, 3.0]) {
      testWidgets('글자 $scale배에서 칩과 조사가 폭보다 넓어도 넘치지 않습니다', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(_app(token(120)));
        expect(tester.takeException(), isNull);
        // 칩 글자가 칩 안에서 줄을 바꿔 폭 안에 머뭅니다.
        expect(
          tester.getSize(find.byType(TermToken)).width,
          lessThanOrEqualTo(120),
        );
        expect(find.text('이', findRichText: true), findsOneWidget);
      });
    }

    testWidgets('폭이 넉넉하면 칩과 조사가 한 줄에 그대로 붙습니다', (tester) async {
      await tester.pumpWidget(_app(token(400)));
      final chip = tester.getRect(find.text('천을귀인'));
      final after = tester.getRect(find.text('이', findRichText: true));
      // 줄바꿈 없음: 칩 글자 한 줄 높이, 조사는 칩 바로 오른쪽에 같은 줄로 붙습니다.
      expect(chip.height, lessThan(_style.fontSize! * _style.height! + 1));
      expect(after.left, greaterThanOrEqualTo(chip.right));
      expect(after.left - chip.right, lessThan(8));
      expect((after.bottom - chip.bottom).abs(), lessThan(4));
    });
  });

  group('SentenceBlock', () {
    testWidgets('preview는 두 줄 말줄임, card·body는 제한이 없습니다', (tester) async {
      Future<RichText> pump(SentenceBlockVariant variant) async {
        await tester.pumpWidget(
          _app(SentenceBlock(variant: variant, text: _siksin)),
        );
        return tester.widget<RichText>(
          find
              .descendant(
                of: find.byType(SentenceBlock),
                matching: find.byType(RichText),
              )
              .first,
        );
      }

      final preview = await pump(SentenceBlockVariant.preview);
      expect(preview.maxLines, 2);
      expect(preview.overflow, TextOverflow.ellipsis);
      expect(_childStyle(preview).fontSize, 14.5);
      final card = await pump(SentenceBlockVariant.card);
      expect(card.maxLines, isNull);
      expect(_childStyle(card).fontSize, 17);
      final body = await pump(SentenceBlockVariant.body);
      expect(_childStyle(body).fontSize, 15);
    });

    testWidgets('slotId는 Key와 Semantics identifier로 붙습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: _siksin,
            slotId: SlotIds.explainSheetTermMeaning,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey(SlotIds.explainSheetTermMeaning)),
        findsOneWidget,
      );
      expect(
        _semantics(
          tester,
          find.byKey(const ValueKey(SlotIds.explainSheetTermMeaning)),
        ).identifier,
        SlotIds.explainSheetTermMeaning,
      );
      handle.dispose();
    });

    group('용어 표시(V28)', () {
      Future<void> pump(WidgetTester tester, SentenceBlock block) =>
          tester.pumpWidget(_app(block));

      testWidgets('term-token이 있는 화면(today) 슬롯은 칩입니다', (tester) async {
        final tapped = <String>[];
        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.card,
            text: _siksin,
            slotId: SlotIds.todayFortuneBody,
            onTerm: tapped.add,
          ),
        );
        expect(find.byType(TermToken), findsOneWidget);
        await tester.tap(find.text('식신'));
        expect(tapped, ['TenGod.SIKSIN']);
      });

      testWidgets('term-token 화면 슬롯이라도 용어 조각이 없으면 onTerm 없이 그립니다', (
        tester,
      ) async {
        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.card,
            text: _text([Segment(text: '오늘은 차분한 하루입니다.')]),
            slotId: SlotIds.todayFortuneBody,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('오늘은 차분한 하루입니다.'), findsOneWidget);
      });

      testWidgets('term-token 화면 슬롯에 용어 조각이 있는데 onTerm이 없으면 assert', (
        tester,
      ) async {
        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.card,
            text: _siksin,
            slotId: SlotIds.todayFortuneBody,
          ),
        );
        expect(tester.takeException(), isA<AssertionError>());
      });

      testWidgets('saju-chart 슬롯도 칩입니다', (tester) async {
        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: _siksin,
            slotId: SlotIds.sajuChartYongsinBasis,
            onTerm: (_) {},
          ),
        );
        expect(find.byType(TermToken), findsOneWidget);
      });

      testWidgets(
        'term-token이 없는 화면(evidence-sheet) 슬롯은 onTerm이 있어도 일반 글자입니다',
        (tester) async {
          await pump(
            tester,
            SentenceBlock(
              variant: SentenceBlockVariant.body,
              text: _siksin,
              slotId: SlotIds.evidenceSheetBasisBody,
              onTerm: (_) {},
            ),
          );
          expect(find.byType(TermToken), findsNothing);
          expect(_allText(tester), '오늘은 식신의 날이에요.');
        },
      );

      testWidgets('slotId가 없으면 일반 글자, 명시한 chip이면 칩입니다', (tester) async {
        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: _siksin,
            onTerm: (_) {},
          ),
        );
        expect(find.byType(TermToken), findsNothing);

        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: _siksin,
            termStyle: TermStyle.chip,
            onTerm: (_) {},
          ),
        );
        expect(find.byType(TermToken), findsOneWidget);
      });

      testWidgets('명시한 plain은 term-token 화면 슬롯에서도 일반 글자(공유 이미지)', (
        tester,
      ) async {
        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.card,
            text: _siksin,
            slotId: SlotIds.todayFortuneBody,
            termStyle: TermStyle.plain,
          ),
        );
        expect(find.byType(TermToken), findsNothing);
      });

      testWidgets('preview(diary-row)는 term-token 화면 슬롯에서도 일반 글자입니다', (
        tester,
      ) async {
        await pump(
          tester,
          SentenceBlock(
            variant: SentenceBlockVariant.preview,
            text: _siksin,
            slotId: SlotIds.todayFortuneBody,
          ),
        );
        expect(find.byType(TermToken), findsNothing);
      });

      test('preview에 chip을 명시하면 assert로 드러납니다', () {
        expect(
          () => SentenceBlock(
            variant: SentenceBlockVariant.preview,
            text: _siksin,
            termStyle: TermStyle.chip,
          ),
          throwsAssertionError,
        );
      });

      testWidgets('RenderedTextView 기본은 plain이라 onTerm이 있어도 일반 글자입니다', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(RenderedTextView(text: _siksin, style: _style, onTerm: (_) {})),
        );
        expect(find.byType(TermToken), findsNothing);
      });
    });

    testWidgets('카드 전체가 버튼인 곳(onTerm 없음)은 용어도 일반 글자입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          SentenceBlock(variant: SentenceBlockVariant.preview, text: _siksin),
        ),
      );
      expect(find.byType(TermToken), findsNothing);
    });

    testWidgets('locked 라벨의 구역 이름은 로케일 문구입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: _siksin,
            locked: true,
          ),
          locale: const Locale('en'),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(
          '${l10n.sajuChartYongsinTitle}, ${l10n.evidenceSheetA11yLocked}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('locked: 본문은 트리에 없고 스크린리더는 구역 이름·"잠김"과 열기만 읽습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(
        _app(
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: _siksin,
            locked: true,
            onOpenLocked: () => opened++,
          ),
        ),
      );
      expect(_allText(tester), isNot(contains('오늘은')));
      expect(find.bySemanticsLabel(RegExp('오늘은')), findsNothing);
      // 구역 이름(a11y.lockedNameSlot) + "잠김" (컴포넌트 2.2.0)
      expect(find.bySemanticsLabel('용신 판정 근거, 잠김'), findsOneWidget);
      // 흐린 자리 채우기 글도 읽히지 않습니다.
      expect(find.bySemanticsLabel(RegExp('가나다')), findsNothing);
      final open = find.bySemanticsLabel('열기');
      expect(_semantics(tester, open).flagsCollection.isLink, isTrue);
      await tester.tap(find.textContaining('열기'));
      expect(opened, 1);
      handle.dispose();
    });
  });

  group('DepthLink', () {
    testWidgets('링크로 읽고 누르면 onTap, 라벨은 글자 그대로입니다', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          DepthLink(
            variant: DepthLinkVariant.block,
            label: '근거 보기',
            onTap: () => taps++,
          ),
        ),
      );
      final data = _semantics(tester, find.bySemanticsLabel('근거 보기'));
      expect(data.flagsCollection.isLink, isTrue);
      await tester.tap(find.textContaining('근거 보기'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('block은 위에 space.12, inline-end는 여백이 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          DepthLink(
            variant: DepthLinkVariant.block,
            label: '근거 보기',
            onTap: () {},
          ),
        ),
      );
      final blockTop = tester.getTopLeft(find.textContaining('근거 보기')).dy;
      await tester.pumpWidget(
        _app(
          DepthLink(
            variant: DepthLinkVariant.inlineEnd,
            label: '근거 보기',
            onTap: () {},
          ),
        ),
      );
      final inlineTop = tester.getTopLeft(find.textContaining('근거 보기')).dy;
      expect(blockTop - inlineTop, Space.s12);
    });
  });

  group('EvidenceSheetBody', () {
    Widget body(
      DepthLinkState state, {
      VoidCallback? onWatchAd,
      VoidCallback? onPass,
      bool showPersonal = true,
    }) => SizedBox(
      width: 360,
      height: 640,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s20),
        child: EvidenceSheetBody(
          state: state,
          title: '식신',
          pillars: const SizedBox(height: 40, child: Text('원국표')),
          basis: state == DepthLinkState.unlocked
              ? _text([Segment(text: '판정 근거 본문')])
              : null,
          source: state == DepthLinkState.unlocked
              ? _text([Segment(text: '원전 인용 본문')])
              : null,
          personal: state == DepthLinkState.unlocked
              ? _text([Segment(text: '내 사주 해석 본문')])
              : null,
          showPersonal: showPersonal,
          onWatchAd: onWatchAd,
          onPass: onPass,
        ),
      ),
    );

    testWidgets('locked: 구역 제목은 또렷하고 본문은 잠기며 안내 영역이 고정됩니다', (tester) async {
      final handle = tester.ensureSemantics();
      var watched = 0;
      var pass = 0;
      await tester.pumpWidget(
        _app(
          body(
            DepthLinkState.locked,
            onWatchAd: () => watched++,
            onPass: () => pass++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('식신'), findsOneWidget);
      expect(find.text('원국표'), findsOneWidget);
      expect(find.bySemanticsLabel('판정 근거, 잠김'), findsOneWidget);
      expect(find.bySemanticsLabel('원전, 잠김'), findsOneWidget);
      expect(find.bySemanticsLabel('내 사주에서는, 잠김'), findsOneWidget);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('ko')).evidenceSheetLockHead,
        ),
        findsOneWidget,
      );
      expect(find.textContaining('광고 한 편'), findsOneWidget);
      // 보상 고지는 광고 버튼보다 먼저(위에) 있습니다.
      expect(
        tester.getTopLeft(find.textContaining('광고 한 편')).dy,
        lessThan(tester.getTopLeft(find.text('광고 보고 열기')).dy),
      );
      await tester.tap(find.text('광고 보고 열기'));
      expect(watched, 1);
      await tester.tap(find.textContaining('광고 제거권'));
      expect(pass, 1);
      expect(find.text('판정 근거 본문'), findsNothing);
      handle.dispose();
    });

    testWidgets('오늘 화면에서 연 근거 시트(showPersonal 없음)는 잠긴 구역이 둘입니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(body(DepthLinkState.locked, showPersonal: false)),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('판정 근거, 잠김'), findsOneWidget);
      expect(find.bySemanticsLabel('원전, 잠김'), findsOneWidget);
      expect(find.bySemanticsLabel('내 사주에서는, 잠김'), findsNothing);
      handle.dispose();
    });

    testWidgets('lockedNoAd: 버튼은 누를 수 없고 안내가 보입니다', (tester) async {
      final handle = tester.ensureSemantics();
      var watched = 0;
      await tester.pumpWidget(
        _app(body(DepthLinkState.lockedNoAd, onWatchAd: () => watched++)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('광고 보고 열기'));
      expect(watched, 0);
      expect(find.textContaining('볼 수 있는 광고가 없어요'), findsOneWidget);
      final data = _semantics(tester, find.bySemanticsLabel('광고 보고 열기'));
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('unlocking: 점 숨쉬기, 스피너 없이 "확인 중"으로 읽고 다시 누를 수 없습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var watched = 0;
      await tester.pumpWidget(
        _app(body(DepthLinkState.unlocking, onWatchAd: () => watched++)),
      );
      // 점이 계속 숨 쉬므로 settle 대신 나타남 시간만큼 흘립니다.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('광고 보고 열기'), findsNothing, reason: '글자 자리에 점 세 개');
      expect(find.byKey(PrimaryButton.dotsKey), findsOneWidget);
      expect(find.bySemanticsLabel('확인 중'), findsOneWidget);
      await tester.tap(find.byKey(EvidenceLockPanel.ctaKey));
      expect(watched, 0);
      handle.dispose();
    });

    testWidgets('unlocked: 안내 영역이 없고 세 구역 본문이 보입니다', (tester) async {
      await tester.pumpWidget(_app(body(DepthLinkState.unlocked)));
      await tester.pumpAndSettle();
      expect(find.text('판정 근거 본문', findRichText: true), findsOneWidget);
      expect(find.text('원전 인용 본문', findRichText: true), findsOneWidget);
      expect(find.text('내 사주 해석 본문', findRichText: true), findsOneWidget);
      expect(find.text('광고 보고 열기'), findsNothing);
      expect(find.text('판정 근거'), findsOneWidget, reason: '구역 제목');
    });

    testWidgets('unlocking에서 unlocked로 바뀌면 light 햅틱과 열림 알림이 한 번 옵니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final haptics = _recordHaptics(tester);
      await tester.pumpWidget(_app(body(DepthLinkState.unlocking)));
      expect(haptics, isEmpty);
      await tester.pumpWidget(_app(body(DepthLinkState.unlocked)));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      final announcement = find.bySemanticsLabel('근거와 해석이 열렸어요');
      expect(announcement, findsOneWidget);
      expect(
        _semantics(tester, announcement).flagsCollection.isLiveRegion,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('처음부터 unlocked면 햅틱도 알림도 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      final haptics = _recordHaptics(tester);
      await tester.pumpWidget(_app(body(DepthLinkState.unlocked)));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      expect(find.bySemanticsLabel('근거와 해석이 열렸어요'), findsNothing);
      handle.dispose();
    });
  });

  group('ReactionButton', () {
    testWidgets('켜면 light 햅틱과 onChanged(true), 끌 때는 햅틱이 없습니다', (tester) async {
      final haptics = _recordHaptics(tester);
      final changes = <bool>[];
      var on = false;
      late StateSetter set;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return ReactionButton(
                on: on,
                onChanged: changes.add,
                semanticsLabel: '이 문장 좋아요',
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(ReactionButton.targetKey));
      expect(changes, [true]);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      set(() => on = true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReactionButton.targetKey));
      expect(changes, [true, false]);
      expect(haptics, hasLength(1), reason: '끌 때는 햅틱이 없음');
    });

    testWidgets('토글 버튼으로 읽고 켜짐 상태를 알립니다', (tester) async {
      final handle = tester.ensureSemantics();
      Future<SemanticsData> data({required bool on}) async {
        await tester.pumpWidget(
          _app(
            ReactionButton(
              on: on,
              onChanged: (_) {},
              semanticsLabel: '이 문장 좋아요',
            ),
          ),
        );
        await tester.pumpAndSettle();
        return _semantics(tester, find.bySemanticsLabel('이 문장 좋아요'));
      }

      final off = await data(on: false);
      expect(off.flagsCollection.isButton, isTrue);
      expect(off.flagsCollection.isToggled, Tristate.isFalse);
      final onData = await data(on: true);
      expect(onData.flagsCollection.isToggled, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('터치 영역은 44px이고 문장 아래 오른쪽 끝에 놓입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 360,
            child: ReactionButton(
              on: false,
              onChanged: (_) {},
              semanticsLabel: '이 문장 좋아요',
            ),
          ),
        ),
      );
      final target = tester.getRect(find.byKey(ReactionButton.targetKey));
      expect(target.size, const Size.square(44));
      expect(target.right, 360);
    });

    testWidgets(
      '켜면 seal fill 안에 Regular 하트(on-primary), 끄면 Light 하트(secondary)',
      (tester) async {
        Future<void> pump({required bool on}) async {
          await tester.pumpWidget(
            _app(
              ReactionButton(
                on: on,
                onChanged: (_) {},
                semanticsLabel: '이 문장 좋아요',
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pump(on: true);
        final colors = tester
            .element(find.byType(ReactionButton))
            .tokens
            .colors;
        final seal = tester.widget<Seal>(find.byType(Seal));
        expect(seal.variant, SealVariant.fill);
        expect(seal.size, SealSize.row);
        var heart = tester.widget<Icon>(
          find.descendant(of: find.byType(Seal), matching: find.byType(Icon)),
        );
        expect(heart.icon, PhosphorIconsRegular.heart);
        expect(heart.color, colors.actionOnPrimary);

        await pump(on: false);
        expect(find.byType(Seal), findsNothing);
        heart = tester.widget<Icon>(find.byType(Icon));
        expect(heart.icon, PhosphorIconsLight.heart);
        expect(heart.color, colors.textSecondary);
      },
    );

    testWidgets('키보드 확정(ActivateIntent)으로도 켜집니다', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          ReactionButton(
            on: false,
            onChanged: changes.add,
            semanticsLabel: '이 문장 좋아요',
          ),
        ),
      );
      Actions.invoke(
        tester.element(find.byKey(ReactionButton.targetKey)),
        const ActivateIntent(),
      );
      expect(changes, [true]);
    });
  });

  group('keep-all (한국어 어절 단위 줄바꿈)', () {
    const narrow = 150.0;
    final text = _text([
      Segment(text: '오늘은 마음이 차분하고 단정해서 '),
      Segment(text: '식신', term: 'TenGod.SIKSIN'),
      Segment(text: '의 기운으로 이야기를 천천히 풀어내기 좋은 하루입니다.'),
    ]);

    RenderParagraph outerParagraph(WidgetTester tester) =>
        tester.renderObject<RenderParagraph>(
          find
              .descendant(
                of: find.byType(RenderedTextView),
                matching: find.byType(RichText),
              )
              .first,
        );

    /// 줄이 시작하는 글자 위치(첫 줄 제외)의 바로 앞 글자들.
    List<String> charsBeforeLineStarts(RenderParagraph paragraph) {
      final plain = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final starts = <int>[];
      double? lineTop;
      for (var i = 0; i < plain.length; i++) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + 1),
        );
        if (boxes.isEmpty) continue;
        final top = boxes.first.top;
        if (lineTop != null && top > lineTop + 1) starts.add(i);
        lineTop = top;
      }
      return [for (final start in starts) plain[start - 1]];
    }

    testWidgets('한국어는 어절 안에서 끊기지 않고 공백에서만 줄이 바뀝니다', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: narrow,
            child: RenderedTextView(
              termStyle: TermStyle.chip,
              text: text,
              style: _style,
              onTerm: (_) {},
            ),
          ),
        ),
      );
      final before = charsBeforeLineStarts(outerParagraph(tester));
      expect(before, isNotEmpty);
      expect(
        before,
        everyElement(anyOf(' ', '\uFFFC')),
        reason: '줄 시작 바로 앞은 공백이거나 칩 덩어리(어절 경계)',
      );
    });

    testWidgets('결합자 없이는 어절 중간에서 끊깁니다(대조)', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: narrow,
            child: Text.rich(
              TextSpan(text: '이야기를천천히풀어내기좋은하루입니다오늘은마음이차분합니다', style: _style),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).last,
      );
      expect(charsBeforeLineStarts(paragraph), isNot(everyElement(' ')));
    });

    testWidgets('스크린리더 라벨과 onTerm 값에는 결합자가 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      final tapped = <String>[];
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: text,
            style: _style,
            onTerm: tapped.add,
          ),
        ),
      );
      expect(
        outerParagraph(tester).text.toPlainText(includeSemanticsLabels: false),
        contains(wordJoiner),
        reason: '그릴 글자에는 결합자가 있음',
      );
      final labels = <String>[];
      void collect(SemanticsNode node) {
        labels.add(node.getSemanticsData().label);
        node.visitChildren((c) {
          collect(c);
          return true;
        });
      }

      collect(_rootSemantics(tester));
      expect(labels.where((l) => l.contains(wordJoiner)), isEmpty);
      expect(labels.any((l) => l.contains('오늘은 마음이')), isTrue);
      await tester.tap(find.text('식신'));
      expect(tapped.single, 'TenGod.SIKSIN');
      handle.dispose();
    });

    for (final locale in const [Locale('en'), Locale('ja')]) {
      testWidgets('${locale.languageCode}에는 적용하지 않습니다', (tester) async {
        await tester.pumpWidget(
          _app(
            RenderedTextView(
              text: _text([Segment(text: 'Today is calm 今日は穏やか')]),
              style: _style,
            ),
            locale: locale,
          ),
        );
        expect(_allText(tester), isNot(contains(wordJoiner)));
      });
    }
  });

  group('붙은 글자와 연속 칩', () {
    List<TermToken> tokens(WidgetTester tester) =>
        tester.widgetList<TermToken>(find.byType(TermToken)).toList();

    String outerText(WidgetTester tester) => tester
        .widget<RichText>(
          find
              .descendant(
                of: find.byType(RenderedTextView),
                matching: find.byType(RichText),
              )
              .first,
        )
        .text
        .toPlainText(includePlaceholders: false);

    testWidgets("영어: 's와 문장부호가 칩에 붙고 라벨에도 묶입니다", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _text([
              Segment(text: 'The ('),
              Segment(text: 'Siksin', term: 'TenGod.SIKSIN'),
              Segment(text: "'s) day, "),
              Segment(text: 'Jeonggwan', term: 'TenGod.JEONGGWAN'),
              Segment(text: ', calm.'),
            ]),
            style: _style,
            onTerm: (_) {},
          ),
          locale: const Locale('en'),
        ),
      );
      final found = tokens(tester);
      expect(found[0].before, '(');
      expect(found[0].after, "'s)");
      expect(found[1].before, isNull);
      expect(found[1].after, ',');
      expect(outerText(tester), 'The  day,  calm.');
      expect(
        find.bySemanticsLabel("See what (Siksin's) means"),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('연속 칩 사이 한 글자 조각은 앞 칩이 가져갑니다', (tester) async {
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _text([
              Segment(text: '식신', term: 'a'),
              Segment(text: '와'),
              Segment(text: '정관', term: 'b'),
            ]),
            style: _style,
            onTerm: (_) {},
          ),
        ),
      );
      final found = tokens(tester);
      expect(found[0].after, '와');
      expect(found[1].before, isNull);
      expect(outerText(tester), isEmpty);
    });

    testWidgets('연속 칩 사이 조각은 앞뒤 칩이 나눠 가집니다', (tester) async {
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _text([
              Segment(text: '식신', term: 'a'),
              Segment(text: '과 그리고 '),
              Segment(text: '정관', term: 'b'),
            ]),
            style: _style,
            onTerm: (_) {},
          ),
        ),
      );
      final found = tokens(tester);
      expect(found[0].after, '과');
      expect(found[1].before, isNull, reason: '"그리고 " 뒤 공백이라 붙은 글자 없음');
      expect(outerText(tester), ' 그리고 ');
    });
  });

  group('inline-end 줄바꿈', () {
    testWidgets('링크가 다음 줄로 넘어가면 마지막 낱말도 함께 넘어갑니다', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 170,
            child: RenderedTextView(
              text: _text([Segment(text: '이유를 한 줄로 적은 문장 마지막낱말')]),
              style: _style,
              trailing: const Text('근거 보기 ›', softWrap: false),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).first,
      );
      final plain = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final lastWord = plain.indexOf('마지막낱말');
      final wordTop = paragraph
          .localToGlobal(
            paragraph.getOffsetForCaret(
              TextPosition(offset: lastWord),
              Rect.zero,
            ),
          )
          .dy;
      final linkTop = tester.getTopLeft(find.text('근거 보기 ›')).dy;
      // 한 줄 높이(24)보다 가깝다 = 같은 줄.
      expect((linkTop - wordTop).abs(), lessThan(12));
    });
  });

  group('IA 슬롯 id', () {
    Set<String> identifiers(WidgetTester tester) {
      final ids = <String>{};
      void visit(SemanticsNode node) {
        ids.add(node.getSemanticsData().identifier);
        node.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(_rootSemantics(tester));
      return ids;
    }

    void expectSlots(
      WidgetTester tester,
      Iterable<String> keys, [
      Iterable<String> semanticsOnly = const [],
    ]) {
      final ids = identifiers(tester);
      for (final id in keys) {
        expect(find.byKey(ValueKey(id)), findsOneWidget, reason: 'Key $id');
        expect(ids, contains(id), reason: 'identifier $id');
      }
      for (final id in semanticsOnly) {
        expect(ids, contains(id), reason: 'identifier $id');
      }
    }

    testWidgets('locked: 구역 제목·본문 자리·안내 영역·접근성 문구', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 360,
            height: 700,
            child: EvidenceSheetBody(
              state: DepthLinkState.locked,
              title: '식신',
              showPersonal: true,
              onWatchAd: () {},
              onPass: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectSlots(
        tester,
        [
          SlotIds.evidenceSheetSectionBasis,
          SlotIds.evidenceSheetSectionSource,
          SlotIds.evidenceSheetSectionPersonal,
          SlotIds.evidenceSheetBasisBody,
          SlotIds.evidenceSheetSourceQuote,
          SlotIds.evidenceSheetPersonalBody,
          SlotIds.evidenceSheetLockHead,
          SlotIds.evidenceSheetLockReward,
          SlotIds.evidenceSheetLockCta,
          SlotIds.evidenceSheetLockPass,
        ],
        [SlotIds.evidenceSheetA11yLocked],
      );
      handle.dispose();
    });

    testWidgets('링크가 감겨도 화살표가 마지막 줄 끝을 따라가고 혼자 줄을 넘지 않습니다', (tester) async {
      // 큰 글자에서 세로로 길어져도 넘치지 않도록 화면을 크게 둡니다.
      tester.view
        ..physicalSize = const Size(800, 4000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pass = find.byKey(const ValueKey(SlotIds.evidenceSheetLockPass));
      var wrapped = 0;
      for (final locale in const [Locale('ko'), Locale('ja')]) {
        final label = lookupAppLocalizations(locale).evidenceSheetLockPass;
        for (final scale in const [1.0, 1.3, 2.0]) {
          for (var width = 160.0; width <= 400; width += 8) {
            await tester.pumpWidget(
              _app(
                locale: locale,
                MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: width,
                    child: EvidenceLockPanel(
                      state: DepthLinkState.locked,
                      onPass: () {},
                      animated: false,
                    ),
                  ),
                ),
              ),
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: pass,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is RichText &&
                      widget.text.toPlainText().contains(label),
                ),
              ),
            );
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            );
            final lineTops = boxes.map((box) => box.top).toSet();
            if (lineTops.length > 1) wrapped++;
            final lastTop = lineTops.reduce((a, b) => a > b ? a : b);
            final lastLine = boxes
                .where((box) => box.top == lastTop)
                .map((box) => box.toRect())
                .reduce((a, b) => a.expandToInclude(b))
                .shift(paragraph.localToGlobal(Offset.zero));
            final plain = paragraph.text.toPlainText();
            final caret = paragraph
                .getBoxesForSelection(
                  TextSelection(
                    baseOffset: plain.length - 1,
                    extentOffset: plain.length,
                  ),
                )
                .single
                .toRect()
                .shift(paragraph.localToGlobal(Offset.zero));
            final where = '$locale ×$scale 폭 $width';
            expect(
              caret.left - lastLine.right,
              inInclusiveRange(-1, Space.s8),
              reason: where,
            );
            expect(
              caret.center.dy,
              inInclusiveRange(lastLine.top, lastLine.bottom),
              reason: where,
            );
          }
        }
      }
      // 전제: 감기는 경우를 충분히 지나갑니다.
      expect(wrapped, greaterThan(10));
    });

    testWidgets('광고 제거권 링크 끝 화살표는 컴포넌트가 그리고 읽히지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 360,
            child: EvidenceLockPanel(
              state: DepthLinkState.locked,
              onPass: () {},
              animated: false,
            ),
          ),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('ko'));
      final pass = find.byKey(const ValueKey(SlotIds.evidenceSheetLockPass));
      final text = tester.widget<RichText>(
        find.descendant(
          of: pass,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(l10n.evidenceSheetLockPass),
          ),
        ),
      );
      // 끝 조각이 화살표 아이콘 글리프이고 링크 색을 이어받습니다.
      final label = (text.text as TextSpan).children!.single as TextSpan;
      final caret = label.children!.last as TextSpan;
      expect(
        caret.text,
        String.fromCharCode(EvidenceLockPanel.passCaret.codePoint),
      );
      expect(
        caret.style!.fontFamily,
        contains(EvidenceLockPanel.passCaret.fontFamily),
      );
      expect(
        text.text.style!.color,
        tester.element(pass).tokens.colors.actionPrimary,
      );
      // 글자는 원고 그대로이고, 링크 이름에 화살표가 섞이지 않습니다.
      expect(
        find.descendant(
          of: pass,
          matching: find.textContaining(l10n.evidenceSheetLockPass),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.evidenceSheetLockPass), findsOneWidget);
      // 단어 연결 문자(U+2060)와 화살표 글리프는 낭독 라벨에 섞이지 않습니다.
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(l10n.evidenceSheetLockPass),
      );
      expect(semantics.label, l10n.evidenceSheetLockPass);
      handle.dispose();
    });

    testWidgets('lockedNoAd: unavailable, unlocking: a11y.checking', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Future<void> pump(DepthLinkState state) async {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 360,
              height: 700,
              child: EvidenceSheetBody(
                state: state,
                title: '식신',
                onWatchAd: () {},
                animated: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(DepthLinkState.lockedNoAd);
      expectSlots(tester, [SlotIds.evidenceSheetLockUnavailable]);
      await pump(DepthLinkState.unlocking);
      expect(identifiers(tester), contains(SlotIds.evidenceSheetA11yChecking));
      handle.dispose();
    });

    testWidgets('unlocked: 구역 제목과 본문 슬롯', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 360,
            height: 700,
            child: EvidenceSheetBody(
              state: DepthLinkState.unlocked,
              title: '식신',
              basis: _text([Segment(text: '근거')]),
              source: _text([Segment(text: '원전')]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectSlots(tester, [
        SlotIds.evidenceSheetSectionBasis,
        SlotIds.evidenceSheetSectionSource,
        SlotIds.evidenceSheetBasisBody,
        SlotIds.evidenceSheetSourceQuote,
      ]);
      handle.dispose();
    });

    testWidgets('잠긴 sentence-block: 열기와 접근성 문구, 반응 버튼: 라벨', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              SentenceBlock(
                variant: SentenceBlockVariant.body,
                text: _siksin,
                locked: true,
                onOpenLocked: () {},
              ),
              ReactionButton(
                on: false,
                onChanged: (_) {},
                semanticsLabel: '이 문장 좋아요',
              ),
            ],
          ),
        ),
      );
      expectSlots(
        tester,
        [SlotIds.sajuChartYongsinOpen, SlotIds.todayReactionLabel],
        [SlotIds.evidenceSheetA11yLocked],
      );
      handle.dispose();
    });
  });

  group('근거 시트 보강', () {
    testWidgets('긴 본문을 스크롤해도 열림 알림 노드가 남습니다', (tester) async {
      final handle = tester.ensureSemantics();
      final long = _text([Segment(text: List.filled(80, '긴 본문 한 줄 ').join())]);
      Widget sheet(DepthLinkState state) => _app(
        SizedBox(
          width: 360,
          height: 300,
          child: EvidenceSheetBody(
            state: state,
            title: '식신',
            basis: state == DepthLinkState.unlocked ? long : null,
            source: state == DepthLinkState.unlocked ? long : null,
            animated: false,
          ),
        ),
      );
      await tester.pumpWidget(sheet(DepthLinkState.unlocking));
      await tester.pumpAndSettle();
      await tester.pumpWidget(sheet(DepthLinkState.unlocked));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      final announcement = find.bySemanticsLabel('근거와 해석이 열렸어요');
      expect(announcement, findsOneWidget);
      expect(
        _semantics(tester, announcement).identifier,
        SlotIds.evidenceSheetA11yUnlocked,
      );
      handle.dispose();
    });

    testWidgets('권한이 있는데 본문이 없으면 debug assert로 드러납니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 360,
            height: 300,
            child: EvidenceSheetBody(
              state: DepthLinkState.unlocked,
              title: '식신',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    test('preview에 onTerm을 주면 assert로 드러납니다', () {
      expect(
        () => SentenceBlock(
          variant: SentenceBlockVariant.preview,
          text: _siksin,
          onTerm: (_) {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('keep-all 안전 경계 (라운드 2)', () {
    const ko = Locale('ko');

    test('이모지 ZWJ·변이 선택자·결합 부호·서로게이트는 그대로 보존됩니다', () {
      const input = '한글 👨\u200D👩\u200D👧 한\uFE0F글 e\u0301한 가\u0301나 😀한 가나';
      final output = applyKeepAll(ko, input);
      expect(output.replaceAll(wordJoiner, ''), input, reason: '코드 유닛 보존');
      // 한글끼리만 결합자가 들어갑니다.
      expect(output, contains('가\u2060나'));
      expect(output, contains('한\uFE0F글'), reason: '변이 선택자 둘레에는 없음');
      expect(output, contains('e\u0301한'));
      expect(output, contains('가\u0301나'));
      expect(output, contains('😀한'), reason: 'BMP 밖 글자 옆에는 없음');
      expect(output, contains('👨\u200D👩\u200D👧'));
    });

    test('한글과 문장부호·숫자·영문 사이는 묶고 공백은 건너뜁니다', () {
      expect(applyKeepAll(ko, '한글.'), '한\u2060글\u2060.');
      expect(applyKeepAll(ko, 'A한 B'), 'A\u2060한 B');
      expect(applyKeepAll(ko, 'ab cd'), 'ab cd', reason: '한글이 없으면 그대로');
    });

    testWidgets('이웃한 일반 조각 경계의 어절도 끊기지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            text: _text([Segment(text: '한국'), Segment(text: '어절 끝')]),
            style: _style,
          ),
        ),
      );
      final plain = tester
          .widget<RichText>(find.byType(RichText).first)
          .text
          .toPlainText(includeSemanticsLabels: false);
      expect(plain, contains('국\u2060어'));
    });

    testWidgets('결합자가 있어도 음수 자간에서 폭이 같습니다', (tester) async {
      await tester.runAsync(ensureGoldenFonts);
      const text = '오늘은 마음이 차분하고 단정해서 이야기를 풀어냅니다';
      double widthOf(List<InlineSpan> spans) => (TextPainter(
        text: TextSpan(
          children: spans,
          style: const TextStyle(
            fontFamily: 'Gowun Dodum',
            fontFamilyFallback: ['Pretendard'],
            fontSize: 15,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).width;
      // 결합자를 글자에 그대로 넣으면 자간이 얹혀 어절이 좁아집니다(대조).
      final naive = widthOf([TextSpan(text: applyKeepAll(ko, text))]);
      final plain = widthOf([const TextSpan(text: text)]);
      expect((naive - plain).abs(), greaterThan(1));
      // keepAllSpans는 결합자 자간을 0으로 두어 폭이 같습니다.
      expect((widthOf(keepAllSpans(ko, text)) - plain).abs(), lessThan(1));
    });
  });

  group('근거 시트 열림 알림과 반응 포커스 (라운드 2)', () {
    testWidgets('열림 알림이 있어도 본문 위치는 그대로입니다', (tester) async {
      Widget sheet(DepthLinkState state) => _app(
        SizedBox(
          width: 360,
          height: 400,
          child: EvidenceSheetBody(
            state: state,
            title: '식신',
            basis: state == DepthLinkState.unlocked
                ? _text([Segment(text: '근거')])
                : null,
            source: state == DepthLinkState.unlocked
                ? _text([Segment(text: '원전')])
                : null,
            animated: false,
          ),
        ),
      );
      await tester.pumpWidget(sheet(DepthLinkState.unlocked));
      await tester.pumpAndSettle();
      final withoutAnnouncement = tester.getTopLeft(find.text('식신'));
      await tester.pumpWidget(sheet(DepthLinkState.unlocking));
      await tester.pumpAndSettle();
      await tester.pumpWidget(sheet(DepthLinkState.unlocked));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('식신')), withoutAnnouncement);
    });

    testWidgets('키보드 초점이 오면 focus.ring 테두리가 나타나고 떠나면 사라집니다', (tester) async {
      Finder ring() => find.descendant(
        of: find.byType(ReactionButton),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.position == DecorationPosition.foreground &&
              (w.decoration as BoxDecoration).border != null,
        ),
      );
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              ReactionButton(
                on: false,
                onChanged: (_) {},
                semanticsLabel: '이 문장 좋아요',
              ),
              const TextField(),
            ],
          ),
        ),
      );
      expect(ring(), findsNothing, reason: '초점 전에는 선이 없음');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ring(), findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(ring()).decoration as BoxDecoration;
      final colors = tester.element(find.byType(ReactionButton)).tokens.colors;
      final border = decoration.border! as Border;
      expect(border.top.color, colors.actionPrimary);
      expect(border.top.width, PatternValues.focusToWidth);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ring(), findsNothing);
    });
  });

  group('라운드 3', () {
    testWidgets('열림 알림 노드는 비어 있지 않은 영역을 갖습니다', (tester) async {
      final handle = tester.ensureSemantics();
      Widget sheet(DepthLinkState state) => _app(
        SizedBox(
          width: 360,
          height: 400,
          child: EvidenceSheetBody(
            state: state,
            title: '식신',
            basis: state == DepthLinkState.unlocked
                ? _text([Segment(text: '근거')])
                : null,
            source: state == DepthLinkState.unlocked
                ? _text([Segment(text: '원전')])
                : null,
            animated: false,
          ),
        ),
      );
      await tester.pumpWidget(sheet(DepthLinkState.unlocking));
      await tester.pumpAndSettle();
      await tester.pumpWidget(sheet(DepthLinkState.unlocked));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel('근거와 해석이 열렸어요'));
      expect(node.rect.isEmpty, isFalse);
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('ko 문장의 낭독 노드: 원문 그대로, 조각나지 않고, 칩은 용어+조사', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          RenderedTextView(
            termStyle: TermStyle.chip,
            text: _text([
              Segment(text: '오늘은 마음이 차분해서 '),
              Segment(text: '식신', term: 'TenGod.SIKSIN'),
              Segment(text: '의 기운으로 이야기를 풀어내요.'),
            ]),
            style: _style,
            onTerm: (_) {},
          ),
        ),
      );
      final labels = <String>[];
      void collect(SemanticsNode node) {
        final label = node.getSemanticsData().label;
        if (label.isNotEmpty) labels.add(label);
        node.visitChildren((c) {
          collect(c);
          return true;
        });
      }

      collect(_rootSemantics(tester));
      expect(labels.where((l) => l.contains(wordJoiner)), isEmpty);
      // 일반 글자는 조각나지 않고 앞·뒤 문장이 각각 한 노드입니다.
      expect(labels.where((l) => l.contains('오늘은 마음이 차분해서')), hasLength(1));
      expect(labels.where((l) => l.contains('기운으로 이야기를 풀어내요.')), hasLength(1));
      expect(labels, contains('식신의 뜻 보기'));
      expect(labels.where((l) => l.contains('TenGod')), isEmpty);
      handle.dispose();
    });
  });
}
