import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/text/line_height.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

Widget _app(Widget child, {Locale locale = const Locale('ko')}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildTheme(brightness: Brightness.light, locale: locale),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

RenderedText _text(String text) =>
    RenderedText(segments: [Segment(text: text)]);

/// [finder] 안 글자의 조각들(첫 단계 자식 TextSpan).
List<TextSpan> _spansOf(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  final root = text.textSpan! as TextSpan;
  return [for (final span in root.children!) span as TextSpan];
}

void main() {
  group('LockVeil', () {
    test('줄 수는 구역마다 고정입니다(elements.json lock.veil.lines)', () {
      expect(LockVeilLines.basis, 3);
      expect(LockVeilLines.source, 2);
      expect(LockVeilLines.personal, 3);
      expect(LockVeilLines.sentenceBlock, 2);
    });

    test('lines는 양수여야 합니다', () {
      const lines = 0;
      expect(
        () => LockVeil(lines: lines, stateLabel: '잠김'),
        throwsAssertionError,
      );
    });

    test('자리값 글자는 언어마다 하나이고 언어끼리 다릅니다', () {
      final ko = LockVeil.placeholderFor(const Locale('ko'));
      final en = LockVeil.placeholderFor(const Locale('en'));
      final ja = LockVeil.placeholderFor(const Locale('ja'));
      expect({ko, en, ja}, hasLength(3));
      for (final text in [ko, en, ja]) {
        expect(text.trim(), isNotEmpty);
        // 사용자에게 보이지 않는 글자여도 D93 금지 글자는 쓰지 않습니다.
        expect(text, isNot(matches(RegExp('[—–·]'))));
      }
      // 모르는 언어는 영어 자리값입니다.
      expect(LockVeil.placeholderFor(const Locale('fr')), en);
      expect(LockVeil.placeholderFor(const Locale('ko', 'KR')), ko);
    });

    testWidgets('앞부분은 또렷하고 같은 줄에서 흐린 자리값이 이어집니다(G1)', (tester) async {
      await tester.pumpWidget(
        _app(
          LockVeil(
            sectionTitle: '판정 근거',
            stateLabel: '잠김',
            lines: LockVeilLines.basis,
            lead: _text('오늘은 용신의'),
          ),
        ),
      );
      final context = tester.element(find.byType(LockVeil));
      final primary = context.tokens.colors.textPrimary;
      final placeholder = LockVeil.placeholderFor(const Locale('ko'));

      // 또렷한 층: 앞부분은 본문색, 자리값은 투명(자리만 차지).
      final clear = _spansOf(tester, find.byKey(LockVeil.clearKey));
      expect(clear.first.text, startsWith('오늘은 용신의'));
      expect(clear.first.style?.color, primary);
      expect(clear.last.text, startsWith(placeholder));
      expect(clear.last.style?.color?.a, 0);

      // 흐린 층: 같은 조각이고 앞부분이 투명, 자리값이 본문색. 흐림과 투명도는 이 층에만.
      final veil = _spansOf(tester, find.byKey(LockVeil.veilKey));
      expect(
        [for (final span in veil) span.text],
        [for (final span in clear) span.text],
      );
      expect(veil.first.style?.color?.a, 0);
      expect(veil.last.style?.color, primary);
      expect(
        find.ancestor(
          of: find.byKey(LockVeil.veilKey),
          matching: find.byType(ImageFiltered),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byKey(LockVeil.clearKey),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(LockVeil.veilKey),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
      // 두 층은 같은 자리에 겹칩니다.
      expect(
        tester.getRect(find.byKey(LockVeil.clearKey)),
        tester.getRect(find.byKey(LockVeil.veilKey)),
      );
    });

    testWidgets('fontFallback을 주면 앞부분 글꼴 대체에 먼저 넣습니다(원전 한자)', (tester) async {
      await tester.pumpWidget(
        _app(
          LockVeil(
            sectionTitle: '원전',
            stateLabel: '잠김',
            lines: LockVeilLines.source,
            lead: _text('궁통보감 「오행총론」\n以義推之'),
            fontFallback: const ['Hanja Test'],
          ),
        ),
      );
      final clear = tester.widget<Text>(find.byKey(LockVeil.clearKey));
      final veil = tester.widget<Text>(find.byKey(LockVeil.veilKey));
      for (final text in [clear, veil]) {
        expect(text.style?.fontFamilyFallback?.first, 'Hanja Test');
        for (final span in (text.textSpan! as TextSpan).children!) {
          expect(
            (span as TextSpan).style?.fontFamilyFallback?.first,
            'Hanja Test',
          );
        }
      }
    });

    testWidgets('앞부분이 없으면 자리값만입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const LockVeil(
            sectionTitle: '원전',
            stateLabel: '잠김',
            lines: LockVeilLines.source,
          ),
        ),
      );
      final clear = _spansOf(tester, find.byKey(LockVeil.clearKey));
      expect(clear, hasLength(1));
      expect(
        clear.single.text,
        startsWith(LockVeil.placeholderFor(const Locale('ko'))),
      );
      expect(clear.single.style?.color?.a, 0);
    });

    for (final (name, lines) in [
      ('판정 근거', LockVeilLines.basis),
      ('원전', LockVeilLines.source),
      ('sentence-block locked', LockVeilLines.sentenceBlock),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name 본문은 앞부분을 포함해 $lines줄입니다(글자 배율 $scale)', (
          tester,
        ) async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: _app(
                LockVeil(
                  sectionTitle: '판정 근거',
                  stateLabel: '잠김',
                  lines: lines,
                  lead: _text('오늘은 용신의'),
                ),
              ),
            ),
          );
          final context = tester.element(find.byType(LockVeil));
          final lineHeight = lineHeightOf(
            context.tokens.typography.sentenceBody,
            MediaQuery.textScalerOf(context),
          );
          final clear = tester.widget<Text>(find.byKey(LockVeil.clearKey));
          expect(clear.maxLines, lines);
          expect(
            tester.getSize(find.byKey(LockVeil.bodyKey)).height,
            moreOrLessEquals(lineHeight * lines, epsilon: 1),
          );
        });
      }
    }

    testWidgets('제목과 본문 사이는 space.8, 자물쇠는 옆 글자 단계입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const LockVeil(
            sectionTitle: '판정 근거',
            stateLabel: '잠김',
            lines: LockVeilLines.basis,
            titleSlotId: 'title',
          ),
        ),
      );
      final title = tester.getRect(find.byKey(const ValueKey('title')));
      final body = tester.getRect(find.byKey(LockVeil.bodyKey));
      expect(body.top - title.bottom, Space.s8);
      final icon = tester.widget<Icon>(find.byType(Icon));
      // type.label.md(13px) 옆이라 size.icon.16입니다.
      expect(icon.size, IconSizeTokens.s16);
    });

    testWidgets('스크린리더는 제목, 앞부분, 잠김 순서로 읽고 자리값은 건너뜁니다', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          LockVeil(
            sectionTitle: '판정 근거',
            stateLabel: '잠김',
            lines: LockVeilLines.basis,
            lead: _text('오늘은 용신의'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('판정 근거, 오늘은 용신의, 잠김'), findsOneWidget);
      final placeholder = LockVeil.placeholderFor(const Locale('ko'));
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(placeholder.trim()))),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('제목 없이 이름만 읽는 자리(sentence-block locked)', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const LockVeil(
            semanticTitle: '용신',
            stateLabel: '잠김',
            lines: LockVeilLines.sentenceBlock,
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.bySemanticsLabel('용신, 잠김'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('본문은 선택할 수 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          LockVeil(
            sectionTitle: '판정 근거',
            stateLabel: '잠김',
            lines: LockVeilLines.basis,
            lead: _text('오늘은 용신의'),
          ),
        ),
      );
      expect(
        find.ancestor(
          of: find.byKey(LockVeil.clearKey),
          matching: find.byType(SelectionContainer),
        ),
        findsWidgets,
      );
    });

    testWidgets('언어에 맞는 자리값을 씁니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const LockVeil(stateLabel: 'Locked', lines: LockVeilLines.source),
          locale: const Locale('en'),
        ),
      );
      final clear = _spansOf(tester, find.byKey(LockVeil.clearKey));
      expect(
        clear.single.text,
        startsWith(LockVeil.placeholderFor(const Locale('en'))),
      );
    });
  });
}
