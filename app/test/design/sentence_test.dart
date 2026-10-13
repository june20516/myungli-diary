import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/sentence/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

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
          RenderedTextView(text: _siksin, style: _style, onTerm: tapped.add),
        ),
      );
      // 조각마다 따로 줄을 바꾸지 않고 Text.rich 하나로 그립니다.
      expect(find.byType(Text), findsWidgets);
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
        _app(RenderedTextView(text: _text([]), style: _style, onTerm: (_) {})),
      );
      expect(find.byType(RichText), findsNothing);
      expect(tester.getSize(find.byType(RenderedTextView)), Size.zero);
    });

    testWidgets('한국어는 용어 뒤 조사까지 한 덩어리로 묶습니다', (tester) async {
      await tester.pumpWidget(
        _app(RenderedTextView(text: _siksin, style: _style, onTerm: (_) {})),
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

    testWidgets('용어 라벨은 "용어 + 풀이 보기"로 읽고 term 값은 읽지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(RenderedTextView(text: _siksin, style: _style, onTerm: (_) {})),
      );
      expect(find.bySemanticsLabel('식신 풀이 보기'), findsOneWidget);
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

    testWidgets('버튼으로 읽고 라벨에 "풀이 보기"가 붙습니다', (tester) async {
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
      final data = _semantics(tester, find.bySemanticsLabel('식신 풀이 보기'));
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
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

    testWidgets('카드 전체가 버튼인 곳(onTerm 없음)은 용어도 일반 글자입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          SentenceBlock(variant: SentenceBlockVariant.preview, text: _siksin),
        ),
      );
      expect(find.byType(TermToken), findsNothing);
    });

    testWidgets('locked: 본문은 트리에 없고 스크린리더는 "잠김"과 열기만 읽습니다', (tester) async {
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
      expect(find.bySemanticsLabel('잠김'), findsOneWidget);
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
      expect(find.text('근거와 해석이 잠겨 있어요'), findsOneWidget);
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
      expect(find.byKey(EvidenceLockPanel.dotsKey), findsOneWidget);
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

    testWidgets('켜진 도장은 seal.fill 색입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          ReactionButton(
            on: true,
            onChanged: (_) {},
            semanticsLabel: '이 문장 좋아요',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ReactionButton.sealKey), findsOneWidget);
    });
  });
}
