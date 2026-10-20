import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
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

TagChip _chip() =>
    TagChip(name: '천을귀인', variant: TagChipVariant.good, onTap: () {});

Widget _scroll(Widget child, {double height = 640}) => inputApp(
  SizedBox(
    width: 360,
    height: height,
    child: SingleChildScrollView(child: child),
  ),
);

void main() {
  group('diary-editor edit', () {
    testWidgets(
      '종이(surface.paper) 위 날짜(caption.md)·질문(caption.lg)·본문(sentence.body)',
      (tester) async {
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
        final dateText = tester.widget<Text>(find.text('2026년 10월 13일 화요일'));
        expect(dateText.style!.fontSize, tokens.typography.captionMd.fontSize);
        final question = tester.widget<Text>(
          find.text('오늘 눈길이 갔던 장면을 적어 볼까요?'),
        );
        expect(question.style!.fontSize, tokens.typography.captionLg.fontSize);
        expect(question.style!.color, tokens.colors.textSecondary);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(
          field.style!.fontFamily,
          tokens.typography.sentenceBody.fontFamily,
        );
        expect(field.minLines, 8);
        expect(field.maxLength, 10000);
        expect(find.text('오늘 있었던 일을 적어 보세요'), findsOneWidget);
      },
    );

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

    testWidgets('저장 순간: 맨 아래로 스크롤 → 도장(fill 64, M.D) + 햅틱 light → 태그 칩', (
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
      expect(find.byType(TagChip), findsNothing);
      final done = editor.playSaveSequence([_chip()]);
      await tester.pumpAndSettle();
      await done;

      final seal = tester.widget<Seal>(find.byType(Seal));
      expect((seal.size, seal.variant), (SealSize.paper, SealVariant.fill));
      expect(find.text('10.13'), findsOneWidget);
      expect(find.byType(TagChip), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final sealRect = tester.getRect(find.byType(Seal));
      expect(viewport.contains(sealRect.center), isTrue, reason: '도장이 보이게 스크롤');
      final chip = tester.getTopLeft(find.byType(TagChip)).dy;
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

  group('diary-editor view', () {
    testWidgets('같은 종이에 도장이 찍힌 채, 아래 태그 칩(간격 8)', (tester) async {
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
      final chips = find.byType(TagChip);
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
      expect(cloud.size, AppIconSize.inline);
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
