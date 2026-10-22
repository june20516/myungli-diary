import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
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

/// 도장 층 안의 Opacity 값.
double _sealOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.byKey(GuideQuestionCard.sealLayerKey),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

/// 도장 층 안 Transform의 확대 배율(없으면 1).
double _sealScale(WidgetTester tester) {
  final transforms = find.descendant(
    of: find.byKey(GuideQuestionCard.sealLayerKey),
    matching: find.byType(Transform),
  );
  if (transforms.evaluate().isEmpty) return 1;
  return tester
      .widget<Transform>(transforms.first)
      .transform
      .getMaxScaleOnAxis();
}

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

    for (final state in [GuideQuestionState.before, GuideQuestionState.after]) {
      testWidgets('${state.name}: 버튼을 누르면 onAction이 한 번 불립니다', (tester) async {
        var taps = 0;
        await tester.pumpWidget(_app(state, onAction: () => taps++));
        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    }

    testWidgets('onAction이 null이면 버튼이 꺼집니다(disabled)', (tester) async {
      await tester.pumpWidget(
        inputApp(
          Center(
            child: GuideQuestionCard(
              state: GuideQuestionState.after,
              eyebrow: '오늘의 질문',
              question: RenderedText(segments: [Segment(text: '질문')]),
              actionLabel: '오늘은 충분히 썼어요',
              onAction: null,
            ),
          ),
        ),
      );
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);
      expect(button.label, '오늘은 충분히 썼어요');
    });

    group('접근성', () {
      testWidgets('묶음 라벨은 "일기 질문"입니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.before));
        expect(find.bySemanticsLabel('일기 질문'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('before에는 "오늘 일기를 썼어요" 상태가 없습니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.before));
        expect(find.bySemanticsLabel('오늘 일기를 썼어요'), findsNothing);
        handle.dispose();
      });

      testWidgets('after면 "오늘 일기를 썼어요"를 상태(status)로 읽고 도장 그림은 읽지 않습니다', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.after));
        final node = tester.getSemantics(find.bySemanticsLabel('오늘 일기를 썼어요'));
        expect(node.label, '오늘 일기를 썼어요');
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
        // seal.stamp keyframe: 시작 scale 1.2·opacity 0, 끝 scale 1·opacity 1.
        expect(_sealScale(tester), closeTo(1.2, 0.001));
        expect(_sealOpacity(tester), closeTo(0, 0.001));
        await tester.pump(const Duration(milliseconds: 100));
        expect(_sealScale(tester), inExclusiveRange(1, 1.2));
        expect(_sealOpacity(tester), inExclusiveRange(0, 0.55));
        final live = find.byType(LiveAnnouncement);
        expect(live, findsOneWidget);
        final data = tester.getSemantics(live).getSemanticsData();
        expect(data.label, '오늘 일기를 썼어요');
        expect(data.flagsCollection.isLiveRegion, isTrue);

        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(_sealScale(tester), closeTo(1, 0.001));
        expect(_sealOpacity(tester), closeTo(1, 0.001));
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

      testWidgets('after에서 before로 돌아오면 도장이 seal.erase로 옅어지다 사라집니다', (
        tester,
      ) async {
        await tester.pumpWidget(_app(GuideQuestionState.after));
        await tester.tap(_toggle);
        await tester.pump();
        // seal.erase: opacity 1에서 0으로. 지우는 동안 도장은 남습니다.
        expect(find.byType(Seal), findsOneWidget);
        expect(_sealOpacity(tester), closeTo(1, 0.001));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(Seal), findsOneWidget);
        expect(_sealOpacity(tester), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.byType(Seal), findsNothing);
        expect(find.byType(LiveAnnouncement), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('동작 줄이기여도 도장은 투명도로 지워집니다', (tester) async {
        await tester.pumpWidget(
          _app(GuideQuestionState.after, reduceMotion: true),
        );
        await tester.tap(_toggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(Seal), findsOneWidget);
        expect(_sealOpacity(tester), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.byType(Seal), findsNothing);
      });

      testWidgets('상태가 바뀌어도 버튼은 같은 State를 씁니다(눌림·포커스 유지)', (tester) async {
        await tester.pumpWidget(_app(GuideQuestionState.before));
        final press = find.descendant(
          of: find.byKey(GuideQuestionCard.buttonKey),
          matching: find.byType(PressInkTarget),
        );
        final before = tester.state(press);
        await tester.tap(_toggle);
        await tester.pumpAndSettle();
        expect(tester.state(press), same(before));
        await tester.tap(_toggle);
        await tester.pumpAndSettle();
        expect(tester.state(press), same(before));
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

    group('full(상한을 채운 날)', () {
      testWidgets('full이면 버튼을 눌러도 onAction이 불리지 않고 햅틱이 없습니다', (tester) async {
        final haptics = recordHaptics(tester);
        var taps = 0;
        await tester.pumpWidget(
          _app(GuideQuestionState.full, onAction: () => taps++),
        );
        await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(taps, 0);
        expect(haptics, isEmpty);
        final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(button.onPressed, isNull);
        expect(button.variant, PrimaryButtonVariant.quiet);
      });

      testWidgets('full은 글자가 disabled.fg이고 질문은 text.secondary입니다', (
        tester,
      ) async {
        await tester.pumpWidget(_app(GuideQuestionState.full));
        final colors = tester.element(find.byType(SentenceBlock)).tokens.colors;
        expect(_questionColor(tester), colors.textSecondary);
        final label = tester.widget<Text>(
          find.descendant(
            of: find.byType(PrimaryButton),
            matching: find.text('쓴 일기 보기'),
          ),
        );
        expect(label.style!.color, colors.disabledFg);
      });

      testWidgets('full에서도 도장이 남습니다', (tester) async {
        await tester.pumpWidget(_app(GuideQuestionState.full));
        final seal = tester.widget<Seal>(find.byType(Seal));
        expect(seal.size, SealSize.card);
        expect(seal.variant, SealVariant.soft);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('full은 after와 같은 상태 낭독(오늘 일기를 썼어요)입니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.full));
        expect(find.bySemanticsLabel('오늘 일기를 썼어요'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('after에서 full로 바뀔 때 "더 쓸 수 없음"을 한 번 낭독하고 full에서는 다시 없습니다', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        Widget card(GuideQuestionState state) => inputApp(
          Center(
            child: GuideQuestionCard(
              state: state,
              eyebrow: '오늘의 질문',
              question: _question(),
              actionLabel: '쓴 일기 보기',
              onAction: () {},
            ),
          ),
        );
        await tester.pumpWidget(card(GuideQuestionState.after));
        expect(find.byType(LiveAnnouncement), findsNothing);
        await tester.pumpWidget(card(GuideQuestionState.full));
        final live = find.byType(LiveAnnouncement);
        expect(live, findsOneWidget);
        final data = tester.getSemantics(live).getSemanticsData();
        expect(data.label, '오늘은 충분히 썼어요');
        expect(data.flagsCollection.isLiveRegion, isTrue);
        // full에서 다시 그려도 같은 문장 그대로입니다(바뀐 문장이 없어 다시 읽지 않음).
        await tester.pumpWidget(card(GuideQuestionState.full));
        expect(
          tester.getSemantics(live).getSemanticsData().label,
          '오늘은 충분히 썼어요',
        );
        handle.dispose();
      });

      testWidgets('처음부터 full이면 낭독 노드(LiveAnnouncement)가 없습니다', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(GuideQuestionState.full));
        await tester.pumpWidget(_app(GuideQuestionState.full));
        expect(find.byType(LiveAnnouncement), findsNothing);
        handle.dispose();
      });

      testWidgets('after에서 full로 바뀌어도 도장은 그대로이고 다시 찍지 않습니다', (tester) async {
        Widget card(GuideQuestionState state) => inputApp(
          Center(
            child: GuideQuestionCard(
              state: state,
              eyebrow: '오늘의 질문',
              question: _question(),
              actionLabel: '쓴 일기 보기',
              onAction: () {},
            ),
          ),
        );
        await tester.pumpWidget(card(GuideQuestionState.after));
        await tester.pumpWidget(card(GuideQuestionState.full));
        // 다시 찍는다면 이 시점에 투명도가 1보다 작습니다.
        await tester.pump(const Duration(milliseconds: 50));
        expect(_sealOpacity(tester), closeTo(1, 0.001));
        // 테마 전환(AnimatedTheme)이 도는 프레임을 지나 도장 움직임이 없는지 봅니다.
        await tester.pumpAndSettle();
        expect(find.byType(Seal), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        expect(_sealOpacity(tester), closeTo(1, 0.001));
      });
    });
  });
}
