import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/keyboard_dismiss.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../input/input_harness.dart';

final _date = CalendarDate(2026, 10, 13);
final _question = RenderedText(
  segments: [Segment(text: '오늘 눈길이 갔던 장면을 적어 볼까요?')],
);

HanjaTag _chip() => HanjaTag(glyph: '貴', label: '천을귀인', onTap: () {});

Widget _scroll(Widget child, {double height = 640}) => inputApp(
  SizedBox(
    width: 360,
    height: height,
    child: SingleChildScrollView(child: child),
  ),
);

void main() {
  group('diary-editor edit', () {
    testWidgets('종이(surface.paper) 안 맨 위 인용 질문, 그 아래 16에 본문(sentence.body). '
        '쓰기에서는 종이 안 날짜를 그리지 않습니다(date-block이 맡음)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _scroll(
          DiaryEditor.edit(
            date: _date,
            controller: controller,
            question: _question,
            placeholder: '오늘 있었던 일을 적어 보세요',
          ),
        ),
      );
      final tokens = tester.element(find.byType(DiaryEditor)).tokens;
      final paper =
          tester
                  .widget<DecoratedBox>(find.byKey(DiaryEditor.paperKey))
                  .decoration
              as BoxDecoration;
      expect(paper.color, tokens.colors.bgSheet);
      expect(paper.borderRadius, BorderRadius.circular(Radii.lg));
      expect(find.text('2026년 10월 13일 화요일'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.style!.fontFamily,
        tokens.typography.sentenceBody.fontFamily,
      );
      expect(field.minLines, 8);
      expect(field.maxLength, 10000);
      expect(find.text('오늘 있었던 일을 적어 보세요'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TextField)).dy -
            tester.getBottomLeft(find.byKey(DiaryEditor.questionKey)).dy,
        Space.s16,
      );
    });

    testWidgets('인용 질문: 왼쪽 3px term.bg 선(radius.full), 안쪽 12, sentence.body 14 '
        'text.secondary', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _scroll(
          DiaryEditor.edit(
            date: _date,
            controller: controller,
            question: _question,
          ),
        ),
      );
      final tokens = tester.element(find.byType(DiaryEditor)).tokens;
      final text = tester.widget<Text>(find.text('오늘 눈길이 갔던 장면을 적어 볼까요?'));
      expect(text.style!.fontSize, DiaryEditor.questionFontSize);
      expect(DiaryEditor.questionFontSize, 14);
      expect(text.style!.fontFamily, tokens.typography.sentenceBody.fontFamily);
      expect(text.style!.color, tokens.colors.textSecondary);

      final line = find.byKey(DiaryEditor.quoteLineKey);
      final lineBox =
          tester.widget<DecoratedBox>(line).decoration as BoxDecoration;
      expect(lineBox.color, tokens.colors.termBg);
      expect(
        lineBox.borderRadius,
        const BorderRadius.all(Radius.circular(Radii.full)),
      );
      final lineRect = tester.getRect(line);
      final textRect = tester.getRect(find.text('오늘 눈길이 갔던 장면을 적어 볼까요?'));
      expect(lineRect.width, DiaryEditor.quoteLineWidth);
      expect(DiaryEditor.quoteLineWidth, 3);
      expect(textRect.left - lineRect.right, Space.s12);
      expect(lineRect.top, textRect.top);
      expect(lineRect.bottom, textRect.bottom);
    });

    testWidgets('질문이 없으면 질문 줄을 그리지 않습니다', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _scroll(DiaryEditor.edit(date: _date, controller: controller)),
      );
      expect(find.byKey(DiaryEditor.questionKey), findsNothing);
    });

    testWidgets('아래 64 도장 자리는 쓰는 중에도 비어 있고 긴 글도 덮지 않습니다', (tester) async {
      final controller = TextEditingController(
        text: List.generate(40, (i) => '줄 $i').join('\n'),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _scroll(DiaryEditor.edit(date: _date, controller: controller)),
      );
      final reserve = find.byKey(DiaryEditor.sealReserveKey);
      expect(tester.getSize(reserve), const Size.square(64));
      expect(find.byType(Seal), findsNothing);
      expect(
        tester.getTopLeft(reserve).dy -
            tester.getBottomLeft(find.byType(TextField)).dy,
        greaterThanOrEqualTo(Space.s12),
      );
      final paper = tester.getRect(find.byKey(DiaryEditor.paperKey));
      expect(tester.getBottomRight(reserve).dx, paper.right - Space.s16);
      expect(tester.getBottomRight(reserve).dy, paper.bottom - Space.s16);
    });

    testWidgets('저장 순간: 맨 아래로 스크롤 → 도장(fill 64, M.D) + 햅틱 light → 대표 태그', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      final controller = TextEditingController(
        text: List.generate(40, (i) => '줄 $i').join('\n'),
      );
      addTearDown(controller.dispose);
      final editor = DiaryEditorController();
      await tester.pumpWidget(
        _scroll(
          DiaryEditor.edit(
            date: _date,
            controller: controller,
            editorController: editor,
          ),
          height: 400,
        ),
      );
      expect(find.byType(HanjaTag), findsNothing);
      final done = editor.playSaveSequence([_chip()]);
      await tester.pumpAndSettle();
      await done;

      final seal = tester.widget<Seal>(find.byType(Seal));
      expect((seal.size, seal.variant), (SealSize.paper, SealVariant.fill));
      expect(find.text('10.13'), findsOneWidget);
      expect(find.byType(HanjaTag), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final sealRect = tester.getRect(find.byType(Seal));
      expect(viewport.contains(sealRect.center), isTrue, reason: '도장이 보이게 스크롤');
      final chip = tester.getTopLeft(find.byType(HanjaTag)).dy;
      expect(
        chip - tester.getBottomLeft(find.byKey(DiaryEditor.paperKey)).dy,
        Space.s16,
      );
    });

    testWidgets('reduce motion이면 도장도 크기·기울기 움직임 없이 나타납니다', (tester) async {
      final controller = TextEditingController(text: '본문');
      addTearDown(controller.dispose);
      final editor = DiaryEditorController();
      await tester.pumpWidget(
        MotionPrefsScope(
          prefs: const MotionPrefs(
            reduceMotion: true,
            reduceTransparency: false,
            lowEnd: false,
          ),
          child: _scroll(
            DiaryEditor.edit(
              date: _date,
              controller: controller,
              editorController: editor,
            ),
          ),
        ),
      );
      final done = editor.playSaveSequence(const []);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final transforms = find.descendant(
        of: find.byKey(DiaryEditor.sealReserveKey),
        matching: find.byType(Transform),
      );
      for (final transform in tester.widgetList<Transform>(transforms)) {
        expect(transform.transform.getMaxScaleOnAxis(), 1);
      }
      await tester.pumpAndSettle();
      await done;
      expect(find.byType(Seal), findsOneWidget);
    });
  });

  group('diary-editor 질문 바꾸기(V82, A115)', () {
    Widget editor(TextEditingController controller, VoidCallback? onSwap) =>
        _scroll(
          DiaryEditor.edit(
            date: _date,
            controller: controller,
            question: _question,
            onSwapQuestion: onSwap,
          ),
        );

    testWidgets('바꾸기가 있으면 질문 오른쪽 8에 arrows-clockwise Light 20 text.secondary, '
        '터치 44', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller, () {}));
      final tokens = tester.element(find.byType(DiaryEditor)).tokens;
      final swap = find.byKey(DiaryEditor.swapKey);
      expect(tester.getSize(swap), const Size.square(44));
      final icon = tester.widget<Icon>(
        find.descendant(of: swap, matching: find.byType(Icon)),
      );
      expect(icon.icon, PhosphorIconsLight.arrowsClockwise);
      expect(icon.size, 20);
      expect(icon.color, tokens.colors.textSecondary);
      final text = tester.getRect(find.text('오늘 눈길이 갔던 장면을 적어 볼까요?'));
      expect(tester.getTopLeft(swap).dx - text.right, greaterThanOrEqualTo(8));
    });

    testWidgets('누르면 콜백, 본문은 그대로이고 본문 초점도 남습니다', (tester) async {
      final controller = TextEditingController(text: '쓰던 글');
      addTearDown(controller.dispose);
      var swaps = 0;
      await tester.pumpWidget(editor(controller, () => swaps++));
      await tester.showKeyboard(find.byType(TextField));
      await tester.tap(find.byKey(DiaryEditor.swapKey));
      await tester.pump();
      expect(swaps, 1);
      expect(controller.text, '쓰던 글');
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('바꾸기가 없으면(후보 하나, 고치기) 아이콘이 없습니다', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller, null));
      expect(find.byKey(DiaryEditor.swapKey), findsNothing);
    });

    testWidgets('스크린리더: 바꾸기는 "질문 바꾸기" 버튼이고 질문은 바뀌면 읽는 live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller, () {}));
      final swap = tester.getSemantics(find.byKey(DiaryEditor.swapKey));
      expect(swap.label, '질문 바꾸기');
      expect(swap.flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel('오늘 눈길이 갔던 장면을 적어 볼까요?'), findsOneWidget);
      final question = tester.getSemantics(
        find.bySemanticsLabel('오늘 눈길이 갔던 장면을 적어 볼까요?'),
      );
      expect(question.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });

  group('diary-editor 키보드 내리기(F-013, V83)', () {
    Widget page(TextEditingController controller) => inputApp(
      Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: DiaryEditor.edit(date: _date, controller: controller),
            ),
          ),
          const SizedBox(height: 200),
        ],
      ),
    );

    bool focused(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

    testWidgets('본문 초점 중 종이 밖을 누르면 초점이 풀립니다', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(page(controller));
      await tester.showKeyboard(find.byType(TextField));
      expect(focused(tester), isTrue);
      await tester.tapAt(const Offset(200, 590));
      await tester.pump();
      expect(focused(tester), isFalse);
    });

    testWidgets('키보드가 보이는 동안 내리기 버튼이 뜨고 누르면 초점이 풀립니다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(page(controller));
      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      expect(find.byType(KeyboardDismissButton), findsOneWidget);
      await tester.tap(find.byType(KeyboardDismissButton));
      await tester.pump();
      expect(focused(tester), isFalse);
    });

    testWidgets('본문 스크롤 아래 여백은 내리기 버튼 44 + 12 자리를 둡니다', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(page(controller));
      expect(
        tester.widget<TextField>(find.byType(TextField)).scrollPadding.bottom,
        greaterThanOrEqualTo(
          KeyboardDismissButton.diameter +
              KeyboardDismissOverlay.gapAboveKeyboard,
        ),
      );
    });
  });

  group('diary-editor view', () {
    testWidgets('같은 종이에 도장이 찍힌 채, 아래 대표 태그(간격 8)', (tester) async {
      await tester.pumpWidget(
        _scroll(
          DiaryEditor.view(
            date: _date,
            body: '회의에서 먼저 말을 꺼냈다.',
            question: _question,
            tags: [_chip(), _chip()],
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('회의에서 먼저 말을 꺼냈다.'), findsOneWidget);
      expect(find.byType(Seal), findsOneWidget);
      // 보기는 저장된 질문을 같은 인용 모양으로, 바꾸기 없이 보입니다.
      expect(find.byKey(DiaryEditor.quoteLineKey), findsOneWidget);
      expect(find.byKey(DiaryEditor.swapKey), findsNothing);
      final chips = find.byType(HanjaTag);
      expect(chips, findsNWidgets(2));
      expect(
        tester.getTopLeft(chips.at(1)).dx - tester.getTopRight(chips.at(0)).dx,
        Space.s8,
      );
    });

    testWidgets('본문은 선택해 복사할 수 있고 스크린리더가 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _scroll(DiaryEditor.view(date: _date, body: '회의에서 먼저 말을 꺼냈다.')),
      );
      final data = tester
          .getSemantics(find.byType(EditableText))
          .getSemanticsData();
      expect(data.value, contains('회의에서 먼저'));
      expect(data.flagsCollection.isReadOnly, isTrue);
      handle.dispose();
    });
  });

  group('draft-indicator', () {
    Widget indicator(DraftIndicatorState state) => inputApp(
      Center(
        child: DraftIndicator(state: state, label: state.name),
      ),
    );

    testWidgets('local은 cloud, saved는 check 아이콘(16 Light), saving은 점 숨쉬기', (
      tester,
    ) async {
      await tester.pumpWidget(indicator(DraftIndicatorState.local));
      final tokens = tester.element(find.byType(DraftIndicator)).tokens;
      final cloud = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(cloud.icon.light, PhosphorIconsLight.cloud);
      expect(cloud.size, AppIconSize.s16);
      final label = tester.widget<Text>(find.text('local'));
      expect(label.style!.fontSize, tokens.typography.captionMd.fontSize);
      expect(label.style!.color, tokens.colors.textSecondary);

      await tester.pumpWidget(indicator(DraftIndicatorState.saving));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BreathingDots), findsOneWidget);
      expect(find.byType(AppIcon), findsNothing);

      await tester.pumpWidget(indicator(DraftIndicatorState.saved));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppIcon>(find.byType(AppIcon)).icon.light,
        PhosphorIconsLight.check,
      );
    });

    testWidgets('스크린리더: 상태 글자를 status로 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(indicator(DraftIndicatorState.saved));
      await tester.pumpAndSettle();
      final data = tester
          .getSemantics(find.bySemanticsLabel('saved'))
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });
}
