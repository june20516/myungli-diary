import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('인용 질문: 왼쪽 3px action.primary 선(radius.full, V102), 안쪽 12, '
        'sentence.body 14 '
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
      expect(lineBox.color, tokens.colors.actionPrimary);
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

  group('diary-editor 질문 떼기와 뗀 자리(V102, D116)', () {
    const questionText = '오늘 눈길이 갔던 장면을 적어 볼까요?';

    /// 질문 상태를 바꿔 다시 그리는 쓰기 종이. [detached]를 바꾸면 `guideStates` 전환입니다.
    Widget editor(
      TextEditingController controller, {
      bool detached = false,
      bool swap = true,
      VoidCallback? onDetach,
      VoidCallback? onAttach,
      RenderedText? question,
      MotionPrefs prefs = const MotionPrefs(
        reduceMotion: false,
        reduceTransparency: false,
        lowEnd: false,
      ),
    }) => MotionPrefsScope(
      prefs: prefs,
      child: _scroll(
        DiaryEditor.edit(
          date: _date,
          controller: controller,
          question: question ?? _question,
          onSwapQuestion: swap && !detached ? () {} : null,
          onDetachQuestion: detached ? null : (onDetach ?? () {}),
          onAttachQuestion: onAttach ?? () {},
          questionDetached: detached,
        ),
      ),
    );

    testWidgets('떼기 x는 바꾸기 바로 뒤 오른쪽 끝, Light 20 text.secondary, 터치 44', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller));
      final tokens = tester.element(find.byType(DiaryEditor)).tokens;
      final remove = find.byKey(DiaryEditor.removeKey);
      final swap = find.byKey(DiaryEditor.swapKey);
      expect(
        tester.getSize(remove),
        const Size.square(DiaryEditor.removeTarget),
      );
      expect(DiaryEditor.removeTarget, 44);
      final icon = tester.widget<Icon>(
        find.descendant(of: remove, matching: find.byType(Icon)),
      );
      expect(icon.icon, PhosphorIconsLight.x);
      expect(icon.size, 20);
      expect(icon.color, tokens.colors.textSecondary);
      // 44 터치 영역끼리 붙여 둡니다(겹치지 않음).
      expect(tester.getTopLeft(remove).dx, tester.getTopRight(swap).dx);
      final paper = tester.getRect(find.byKey(DiaryEditor.paperKey));
      expect(tester.getTopRight(remove).dx, paper.right - Space.s16);
      // 아이콘은 질문 첫 줄 높이에 맞춥니다(`align: first-line`).
      expect(
        tester.getCenter(find.byIcon(PhosphorIconsLight.x)).dy,
        moreOrLessEquals(
          tester.getCenter(find.byIcon(PhosphorIconsLight.arrowsClockwise)).dy,
        ),
      );
    });

    testWidgets('바꾸기가 없으면(후보 하나) 떼기가 질문 글 바로 뒤(space.8) 오른쪽 끝입니다', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller, swap: false));
      expect(find.byKey(DiaryEditor.swapKey), findsNothing);
      final remove = find.byKey(DiaryEditor.removeKey);
      final text = tester.getRect(find.text(questionText));
      expect(
        tester.getTopLeft(remove).dx - text.right,
        greaterThanOrEqualTo(DiaryEditor.questionActionsGap),
      );
      final paper = tester.getRect(find.byKey(DiaryEditor.paperKey));
      expect(tester.getTopRight(remove).dx, paper.right - Space.s16);
    });

    testWidgets('떼기를 누르면 콜백, 본문과 본문 초점(키보드)은 그대로입니다', (tester) async {
      final controller = TextEditingController(text: '쓰던 글');
      addTearDown(controller.dispose);
      var detaches = 0;
      await tester.pumpWidget(editor(controller, onDetach: () => detaches++));
      await tester.showKeyboard(find.byType(TextField));
      await tester.tap(find.byKey(DiaryEditor.removeKey));
      await tester.pump();
      expect(detaches, 1);
      expect(controller.text, '쓰던 글');
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('뗀 자리: 세로선 없이 본문과 같은 시작선, 권유 글자 14 invite.fg와 '
        '뒤 space.4 말풍선(옆 글자 크기, 같은 색)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller, detached: true));
      final tokens = tester.element(find.byType(DiaryEditor)).tokens;
      expect(find.byKey(DiaryEditor.quoteLineKey), findsNothing);
      expect(find.text(questionText), findsNothing);
      expect(find.byKey(DiaryEditor.swapKey), findsNothing);
      expect(find.byKey(DiaryEditor.removeKey), findsNothing);

      final label = find.text('무엇을 쓸지 고민인가요?');
      final style = tester.widget<Text>(label).style!;
      expect(style.fontSize, DiaryEditor.questionFontSize);
      expect(style.fontFamily, tokens.typography.sentenceBody.fontFamily);
      expect(style.color, tokens.colors.inviteFg);
      final body = tester.getRect(find.byType(TextField));
      expect(tester.getTopLeft(label).dx, body.left);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(DiaryEditor.detachedIconKey),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, PhosphorIconsLight.chatTeardropDots);
      expect(icon.size, AppIconSize.adjacentText(14).logical);
      expect(icon.color, tokens.colors.inviteFg);
      expect(
        tester.getTopLeft(find.byKey(DiaryEditor.detachedIconKey)).dx -
            tester.getTopRight(label).dx,
        DiaryEditor.detachedIconGap,
      );
      expect(DiaryEditor.detachedIconGap, Space.s4);
      final line = tester.getRect(find.byKey(DiaryEditor.detachedKey));
      expect(line.height, greaterThanOrEqualTo(DiaryEditor.detachedMinHeight));
      // 줄 전체가 버튼입니다.
      expect(line.width, body.width);
      expect(body.top - line.bottom, Space.s16);
    });

    testWidgets('권유 줄을 누르면 콜백, 본문과 본문 초점은 그대로입니다', (tester) async {
      final controller = TextEditingController(text: '쓰던 글');
      addTearDown(controller.dispose);
      var attaches = 0;
      await tester.pumpWidget(
        editor(controller, detached: true, onAttach: () => attaches++),
      );
      await tester.showKeyboard(find.byType(TextField));
      final line = tester.getRect(find.byKey(DiaryEditor.detachedKey));
      // 글자 밖 줄 오른쪽 끝을 눌러도 됩니다(줄 전체가 버튼).
      await tester.tapAt(line.centerRight - const Offset(4, 0));
      await tester.pump();
      expect(attaches, 1);
      expect(controller.text, '쓰던 글');
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('전환: 앞 상태 disappear.seep과 새 상태 appear.seep이 같은 자리에서 동시에, '
        '자리 높이는 새 상태로 바로 바뀝니다', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller, detached: true));
      final detachedBodyTop = tester.getTopLeft(find.byType(TextField)).dy;
      await tester.pumpWidget(editor(controller));
      final attachedBodyTop = tester.getTopLeft(find.byType(TextField)).dy;
      await tester.pumpAndSettle();
      expect(find.byKey(DiaryEditor.detachedKey), findsNothing);
      expect(tester.getTopLeft(find.byType(TextField)).dy, attachedBodyTop);

      await tester.pumpWidget(editor(controller, detached: true));
      // 본문은 움직임 없이 새 높이 자리로 바로 옮겨 갑니다.
      expect(tester.getTopLeft(find.byType(TextField)).dy, detachedBodyTop);
      await tester.pump(const Duration(milliseconds: 100));
      // 같은 자리에서 둘 다 그려지는 중(앞 상태는 사라지는 중, 새 상태는 나타나는 중)입니다.
      expect(find.text(questionText), findsOneWidget);
      expect(find.text('무엇을 쓸지 고민인가요?'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(DiaryEditor.quoteLineKey)).dy,
        tester.getTopLeft(find.byKey(DiaryEditor.detachedKey)).dy,
      );
      // 질문 안쪽 바꾸기 전환의 투명도까지 곱한 보이는 투명도입니다.
      double opacityOf(Finder finder) => tester
          .widgetList<Opacity>(
            find.ancestor(of: finder, matching: find.byType(Opacity)),
          )
          .fold(1, (value, opacity) => value * opacity.opacity);
      final outgoing = opacityOf(find.text(questionText));
      final incoming = opacityOf(find.text('무엇을 쓸지 고민인가요?'));
      expect(outgoing, inExclusiveRange(0, 1));
      expect(incoming, inExclusiveRange(0, 1));
      // 사라짐(200ms)이 나타남(320ms)보다 먼저 끝납니다.
      await tester.pump(const Duration(milliseconds: 110));
      expect(find.text(questionText), findsNothing);
      expect(find.text('무엇을 쓸지 고민인가요?'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(opacityOf(find.text('무엇을 쓸지 고민인가요?')), 1);
    });

    testWidgets('동작 줄이기: 전환은 투명도만(흐림 없음)입니다', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      const reduced = MotionPrefs(
        reduceMotion: true,
        reduceTransparency: false,
        lowEnd: false,
      );
      await tester.pumpWidget(editor(controller, prefs: reduced));
      await tester.pumpWidget(
        editor(controller, detached: true, prefs: reduced),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final filters = tester.widgetList<ImageFiltered>(
        find.ancestor(
          of: find.text('무엇을 쓸지 고민인가요?'),
          matching: find.byType(ImageFiltered),
        ),
      );
      expect(filters.where((filter) => filter.enabled), isEmpty);
      await tester.pumpAndSettle();
    });

    /// 접근성 채널로 나가는 이벤트(`{'type': 'focus', 'nodeId': ...}` 등)를 모읍니다.
    List<Map<Object?, Object?>> captureA11yEvents(WidgetTester tester) {
      final events = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            events.add(message! as Map<Object?, Object?>);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      return events;
    }

    List<Object?> focusedNodes(List<Map<Object?, Object?>> events) => [
      for (final event in events)
        if (event['type'] == 'focus') event['nodeId'],
    ];

    testWidgets('스크린리더: 떼기는 "질문 없이 쓰기" 버튼, 권유 줄은 글자 그대로 읽는 버튼', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller));
      final remove = tester.getSemantics(find.byKey(DiaryEditor.removeKey));
      expect(remove.label, '질문 없이 쓰기');
      expect(remove.flagsCollection.isButton, isTrue);

      await tester.pumpWidget(editor(controller, detached: true));
      await tester.pump(const Duration(milliseconds: 50));
      // 사라지는 질문은 읽지 않습니다(지금 의미 트리 기준).
      expect(find.semantics.byLabel(questionText), findsNothing);
      await tester.pumpAndSettle();
      final attach = tester.getSemantics(find.byKey(DiaryEditor.detachedKey));
      // 라벨은 권유 글자 그대로, hint는 "질문 추가"입니다(#1013, V102).
      expect(attach.label, '무엇을 쓸지 고민인가요?');
      expect(attach.hint, '질문 추가');
      expect(attach.flagsCollection.isButton, isTrue);
      expect(attach.flagsCollection.isEnabled, Tristate.isTrue);
      // 초점 이동이 읽으므로 live region은 두지 않습니다(두 번 읽지 않게).
      expect(attach.flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });

    testWidgets('떼면 스크린리더 초점이 권유 줄로 옮겨 가고 본문 입력 초점은 그대로입니다', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController(text: '쓰던 글');
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller));
      await tester.showKeyboard(find.byType(TextField));
      final events = captureA11yEvents(tester);
      await tester.pumpWidget(editor(controller, detached: true));
      await tester.pump();
      final line = tester.getSemantics(find.byKey(DiaryEditor.detachedKey));
      expect(focusedNodes(events), [line.id]);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('다시 붙이면 스크린리더 초점이 질문으로 가고, 그때는 알림을 끄며 바꾸면 다시 켭니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(editor(controller, detached: true));
      final events = captureA11yEvents(tester);
      await tester.pumpWidget(editor(controller));
      await tester.pump();
      final question = tester.getSemantics(find.bySemanticsLabel(questionText));
      expect(focusedNodes(events), [question.id]);
      // 초점 이동이 질문을 읽으므로 같은 글을 live region으로 또 읽지 않습니다.
      expect(question.flagsCollection.isLiveRegion, isFalse);
      await tester.pumpAndSettle();

      const swapped = '오늘 들은 말 중에 기억에 남는 게 있나요?';
      await tester.pumpWidget(
        editor(
          controller,
          question: RenderedText(segments: [Segment(text: swapped)]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(swapped))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      // 바꾸기는 초점을 옮기지 않습니다(바꾸기 버튼에 남음).
      expect(focusedNodes(events), hasLength(1));
      handle.dispose();
    });

    testWidgets('처음 열 때는 스크린리더 초점을 옮기지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final events = captureA11yEvents(tester);
      await tester.pumpWidget(editor(controller, detached: true));
      await tester.pump();
      expect(focusedNodes(events), isEmpty);
      handle.dispose();
    });

    testWidgets('떼고 바로 붙여도(사라지는 중) 질문과 떼기는 하나씩만 읽히고 눌립니다', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var detaches = 0;
      await tester.pumpWidget(editor(controller, onDetach: () => detaches++));
      await tester.pumpWidget(editor(controller, detached: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(editor(controller, onDetach: () => detaches++));
      await tester.pump(const Duration(milliseconds: 50));
      // 옛 질문(사라지는 중)과 새 질문이 함께 그려지지만 읽히고 눌리는 것은 새 것 하나입니다.
      expect(find.text(questionText), findsNWidgets(2));
      expect(find.semantics.byLabel(questionText), findsOne);
      expect(find.semantics.byLabel('질문 없이 쓰기'), findsOne);
      // 두 x가 같은 자리에 있어도 사라지는 쪽은 누를 수 없어 한 번만 불립니다.
      await tester.tapAt(
        tester.getCenter(find.byKey(DiaryEditor.removeKey).last),
      );
      expect(detaches, 1);
      await tester.pumpAndSettle();
      expect(find.text(questionText), findsOneWidget);
      handle.dispose();
    });

    testWidgets('누를 곳이 없으면(저장 뒤) 권유 줄은 꺼진 버튼으로 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _scroll(
          DiaryEditor.edit(
            date: _date,
            controller: controller,
            question: _question,
            questionDetached: true,
          ),
        ),
      );
      final line = tester.getSemantics(find.byKey(DiaryEditor.detachedKey));
      expect(line.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('붙일 질문이 없으면(whenNoQuestion) 뗀 상태여도 질문 자리 전체가 없습니다', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _scroll(
          DiaryEditor.edit(
            date: _date,
            controller: controller,
            questionDetached: true,
            onAttachQuestion: () {},
          ),
        ),
      );
      expect(find.byKey(DiaryEditor.detachedKey), findsNothing);
      expect(find.byKey(DiaryEditor.questionKey), findsNothing);
      final paper = tester.getRect(find.byKey(DiaryEditor.paperKey));
      expect(
        tester.getTopLeft(find.byType(TextField)).dy - paper.top,
        Space.s16,
      );
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
