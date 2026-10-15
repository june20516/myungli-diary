import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import '../input/input_harness.dart';

const _questionText = '오늘 가장 오래 마음에 남은 장면은 무엇인가요?';

RenderedText _question() =>
    RenderedText(segments: [Segment(text: _questionText)]);

class _Host extends StatefulWidget {
  const new({required this.initial, required this.onAction});

  final GuideQuestionState initial;
  final VoidCallback onAction;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late GuideQuestionState state = widget.initial;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 360,
        child: GuideQuestionCard(
          state: state,
          eyebrow: '오늘의 질문',
          question: _question(),
          actionLabel: state == GuideQuestionState.before ? '일기 쓰기' : '쓴 일기 보기',
          onAction: widget.onAction,
          questionSlotId: SlotIds.todayGuideQuestion,
          actionSlotId: SlotIds.todayGuideCta,
        ),
      ),
      TextButton(
        key: const ValueKey('toggle'),
        onPressed: () => setState(
          () => state = state == GuideQuestionState.before
              ? GuideQuestionState.after
              : GuideQuestionState.before,
        ),
        child: const Text('전환'),
      ),
    ],
  );
}

Widget _app(
  GuideQuestionState initial, {
  VoidCallback? onAction,
  bool reduceMotion = false,
  Brightness brightness = Brightness.light,
}) => inputApp(
  MotionPrefsScope(
    prefs: MotionPrefs(
      reduceMotion: reduceMotion,
      reduceTransparency: false,
      lowEnd: false,
    ),
    child: Center(
      child: _Host(initial: initial, onAction: onAction ?? () {}),
    ),
  ),
  brightness: brightness,
);

Finder get _toggle => find.byKey(const ValueKey('toggle'));

Color _questionColor(WidgetTester tester) => tester
    .widget<RenderedTextView>(
      find.descendant(
        of: find.byType(SentenceBlock),
        matching: find.byType(RenderedTextView),
      ),
    )
    .style
    .color!;

void main() {
  group('guide-question-card', () {
    testWidgets('before: filled 버튼이고 도장이 없으며 질문은 text.primary입니다', (
      tester,
    ) async {
      await tester.pumpWidget(_app(GuideQuestionState.before));
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.variant, PrimaryButtonVariant.filled);
      expect(button.label, '일기 쓰기');
      expect(find.byType(Seal), findsNothing);
      expect(
        tester.widget<SentenceBlock>(find.byType(SentenceBlock)).variant,
        SentenceBlockVariant.card,
      );
      final colors = tester.element(find.byType(SentenceBlock)).tokens.colors;
      expect(_questionColor(tester), colors.textPrimary);
      expect(find.text('오늘의 질문'), findsOneWidget);
    });

    testWidgets(
      'after: quiet 버튼, 52px soft 도장이 버튼 글자 뒤 층, 질문은 text.secondary',
      (tester) async {
        await tester.pumpWidget(_app(GuideQuestionState.after));
        final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(button.variant, PrimaryButtonVariant.quiet);
        final seal = tester.widget<Seal>(find.byType(Seal));
        expect(seal.variant, SealVariant.soft);
        expect(seal.size, SealSize.card);
        expect(tester.getSize(find.byType(Seal)), const Size.square(52));

        final colors = tester.element(find.byType(SentenceBlock)).tokens.colors;
        expect(_questionColor(tester), colors.textSecondary);
        expect(button.labelColor, colors.sealOnSoft);

        // 도장은 버튼보다 먼저 그려져(뒤 층) 글자를 가리지 않고, 가운데에 놓입니다.
        final stack = find.ancestor(
          of: find.byKey(GuideQuestionCard.sealLayerKey),
          matching: find.byType(Stack),
        );
        final children = tester.widget<Stack>(stack.first).children;
        expect(children.first.key, GuideQuestionCard.sealLayerKey);
        expect(children.last, isA<PrimaryButton>());
        expect(
          tester.getCenter(find.byType(Seal)).dx,
          closeTo(tester.getCenter(find.byType(PrimaryButton)).dx, 0.5),
        );
      },
    );

    testWidgets('도장은 터치를 가로채지 않습니다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(GuideQuestionState.after, onAction: () => taps++),
      );
      await tester.tap(find.byType(Seal), warnIfMissed: false);
      expect(taps, 1);
    });

    testWidgets('질문과 버튼에 슬롯 id를 붙입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(GuideQuestionState.before));
      expect(
        find.byKey(const ValueKey(SlotIds.todayGuideQuestion)),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(SlotIds.todayGuideCta), findsOneWidget);
      handle.dispose();
    });

    for (final state in GuideQuestionState.values) {
      testWidgets('${state.name}: 버튼을 누르면 onAction이 한 번 불립니다', (tester) async {
        var taps = 0;
        await tester.pumpWidget(_app(state, onAction: () => taps++));
        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    }

    group('접근성', () {
      testWidgets('묶음 라벨은 "질문"입니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.before));
        expect(find.bySemanticsLabel('질문'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('before에는 "오늘 일기 씀" 상태가 없습니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.before));
        expect(find.bySemanticsLabel('오늘 일기 씀'), findsNothing);
        handle.dispose();
      });

      testWidgets('after면 "오늘 일기 씀"을 상태(status)로 읽고 도장 그림은 읽지 않습니다', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.after));
        final node = tester.getSemantics(find.bySemanticsLabel('오늘 일기 씀'));
        expect(node.label, '오늘 일기 씀');
        handle.dispose();
      });
    });

    group('before에서 after로 바뀔 때', () {
      testWidgets('도장이 seal.stamp로 나타나고 상태 알림이 한 번 갑니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.before));
        expect(tester.binding.transientCallbackCount, 0);

        await tester.tap(_toggle);
        await tester.pump();
        expect(find.byType(Seal), findsOneWidget);
        expect(
          tester.binding.transientCallbackCount,
          greaterThan(0),
          reason: '도장이 찍히는 움직임이 돕니다',
        );
        expect(
          find.descendant(
            of: find.byKey(GuideQuestionCard.sealLayerKey),
            matching: find.byType(Transform),
          ),
          findsWidgets,
          reason: 'seal.stamp는 크기가 줄며 찍힙니다',
        );
        final live = find.byType(LiveAnnouncement);
        expect(live, findsOneWidget);
        final data = tester.getSemantics(live).getSemanticsData();
        expect(data.label, '오늘 일기 씀');
        expect(data.flagsCollection.isLiveRegion, isTrue);

        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        handle.dispose();
      });

      testWidgets('동작 줄이기면 크기 변화 없이 투명도로만 나타나고 알림은 갑니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(GuideQuestionState.before, reduceMotion: true),
        );
        await tester.tap(_toggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(Seal), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(GuideQuestionCard.sealLayerKey),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
        expect(find.byType(LiveAnnouncement), findsOneWidget);
        await tester.pumpAndSettle();
        handle.dispose();
      });

      testWidgets('after에서 before로 돌아오면 도장이 사라집니다', (tester) async {
        await tester.pumpWidget(_app(GuideQuestionState.before));
        await tester.tap(_toggle);
        await tester.pumpAndSettle();
        await tester.tap(_toggle);
        await tester.pumpAndSettle();
        expect(find.byType(Seal), findsNothing);
        expect(find.byType(LiveAnnouncement), findsNothing);
      });
    });

    testWidgets('처음부터 after면 움직임도 알림도 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(GuideQuestionState.after));
      expect(find.byType(Seal), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byType(LiveAnnouncement), findsNothing);
      handle.dispose();
    });
  });
}
