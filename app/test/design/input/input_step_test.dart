import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import 'input_harness.dart';

InputStep _step({
  InputStepVariant variant = InputStepVariant.onboarding,
  String? error,
  int? step = 2,
  int? stepCount = 4,
  VoidCallback? onAction,
  bool actionLoading = false,
  String? help,
}) => InputStep(
  screenId: 'onboard-call',
  variant: variant,
  question: '뭐라고 부를까요?',
  input: const SizedBox(height: 52, child: Placeholder()),
  help: help,
  error: error,
  actionLabel: '다음',
  onAction: onAction ?? () {},
  actionLoading: actionLoading,
  step: step,
  stepCount: stepCount,
);

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

void main() {
  group('input-step', () {
    testWidgets('질문·도움말·버튼 글자를 그립니다', (tester) async {
      await tester.pumpWidget(inputApp(_step(help: '실명이 아니어도 돼요')));
      await tester.pumpAndSettle();
      expect(find.text('뭐라고 부를까요?'), findsOneWidget);
      expect(find.text('실명이 아니어도 돼요'), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
    });

    testWidgets('error가 없으면 오류 줄이 없고 버튼이 눌립니다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(inputApp(_step(onAction: () => pressed++)));
      await tester.pumpAndSettle();
      expect(_button(tester).onPressed, isNotNull);
      await tester.tap(find.text('다음'));
      expect(pressed, 1);
    });

    testWidgets('error가 있으면 버튼 onPressed가 비활성입니다', (tester) async {
      await tester.pumpWidget(inputApp(_step(error: '범위를 벗어났어요')));
      await tester.pumpAndSettle();
      expect(find.text('범위를 벗어났어요'), findsOneWidget);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('onAction이 null이어도 비활성입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          const InputStep(
            screenId: 'onboard-call',
            variant: InputStepVariant.standalone,
            question: '질문',
            input: SizedBox(),
            actionLabel: '다음',
            onAction: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('actionLoading이면 버튼이 loading입니다', (tester) async {
      await tester.pumpWidget(inputApp(_step(actionLoading: true)));
      await tester.pump(const Duration(seconds: 1));
      expect(_button(tester).loading, isTrue);
    });

    testWidgets('오류 줄 Semantics가 liveRegion이고 글자를 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_step(error: '범위를 벗어났어요')));
      await tester.pumpAndSettle();
      final data = tester
          .getSemantics(find.bySemanticsLabel('범위를 벗어났어요'))
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('오류가 풀리면 오류 줄이 사라집니다', (tester) async {
      await tester.pumpWidget(inputApp(_step(error: '범위를 벗어났어요')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(inputApp(_step()));
      await tester.pumpAndSettle();
      expect(find.text('범위를 벗어났어요'), findsNothing);
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('onboarding: step 2 of 4면 진행 막대 라벨이 "4단계 중 2단계"입니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_step()));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('4단계 중 2단계'), findsOneWidget);
      expect(find.byKey(InputStep.progressKey), findsOneWidget);
      handle.dispose();
    });

    testWidgets('진행 막대는 3px이고 채움은 step/stepCount입니다', (tester) async {
      await tester.pumpWidget(inputApp(_step()));
      await tester.pumpAndSettle();
      final track = tester.getSize(find.byKey(InputStep.progressKey));
      final fill = tester.getSize(find.byKey(InputStep.progressFillKey));
      expect(track.height, 3);
      expect(fill.width, closeTo(track.width / 2, 0.01));
    });

    testWidgets('standalone이면 진행 막대가 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(_step(variant: InputStepVariant.standalone)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(InputStep.progressKey), findsNothing);
      expect(find.bySemanticsLabel('4단계 중 2단계'), findsNothing);
      handle.dispose();
    });

    testWidgets('진행 막대 채움 너비만 Motion.medium 동안 늘어납니다', (tester) async {
      await tester.pumpWidget(inputApp(_step(step: 1)));
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byKey(InputStep.progressFillKey));
      await tester.pumpWidget(inputApp(_step()));
      await tester.pump(Motion.medium ~/ 2);
      final mid = tester.getSize(find.byKey(InputStep.progressFillKey));
      expect(mid.width, greaterThan(before.width));
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byKey(InputStep.progressFillKey));
      expect(after.width, greaterThan(mid.width));
    });

    testWidgets('키보드가 300 올라오면 버튼 아래 끝이 키보드 위 space.16입니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: inputApp(_step(), scaffold: false),
        ),
      );
      await tester.pumpAndSettle();
      final bottom = tester.getBottomLeft(find.byType(PrimaryButton)).dy;
      expect(bottom, 800 - 300 - Space.s16);
    });

    testWidgets('Scaffold 안에서도 키보드 위 space.16입니다(이중으로 띄우지 않음)', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1
        ..viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(inputApp(_step()));
      await tester.pumpAndSettle();
      final bottom = tester.getBottomLeft(find.byType(PrimaryButton)).dy;
      expect(bottom, 800 - 300 - Space.s16);
    });

    testWidgets('키보드가 없으면 버튼 아래 여백이 space.16입니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(inputApp(_step()));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byType(PrimaryButton)).dy,
        800 - Space.s16,
      );
      expect(
        tester.getTopLeft(find.byType(PrimaryButton)).dx,
        Space.s20,
        reason: '좌우 여백 space.20',
      );
    });

    testWidgets('selectToAdvance: 고르면 바로 넘어가는 단계에는 아래 버튼이 없고, '
        '내용이 키보드 위 space.16까지 스크롤됩니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: inputApp(
            const InputStep.selectToAdvance(
              screenId: 'birthplace',
              variant: InputStepVariant.onboarding,
              step: 5,
              stepCount: 5,
              question: '어디서 태어났나요?',
              input: SizedBox(height: 2000, child: Placeholder()),
              help: '출생 시간대를 정해요.',
            ),
            scaffold: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrimaryButton), findsNothing);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect((scroll.padding! as EdgeInsets).bottom, 300 + Space.s16);
    });

    testWidgets('preface는 질문 아래 space.24, 입력 위 space.24에 놓입니다', (tester) async {
      const prefaceKey = ValueKey('preface');
      const inputKey = ValueKey('input');
      for (final step in [
        const InputStep(
          screenId: 'onboard-call',
          variant: InputStepVariant.standalone,
          question: '질문',
          preface: SizedBox(key: prefaceKey, height: 40),
          input: SizedBox(key: inputKey, height: 52),
          actionLabel: '다음',
          onAction: null,
        ),
        const InputStep.selectToAdvance(
          screenId: 'birthplace',
          variant: InputStepVariant.standalone,
          question: '질문',
          preface: SizedBox(key: prefaceKey, height: 40),
          input: SizedBox(key: inputKey, height: 52),
        ),
      ]) {
        await tester.pumpWidget(inputApp(step));
        await tester.pumpAndSettle();
        final questionBottom = tester.getBottomLeft(find.text('질문')).dy;
        final prefaceRect = tester.getRect(find.byKey(prefaceKey));
        expect(prefaceRect.top, questionBottom + Space.s24);
        expect(
          tester.getTopLeft(find.byKey(inputKey)).dy,
          prefaceRect.bottom + Space.s24,
        );
      }
    });

    testWidgets('preface가 없으면 입력이 질문 아래 space.24 그대로입니다', (tester) async {
      const inputKey = ValueKey('input');
      await tester.pumpWidget(
        inputApp(
          const InputStep(
            screenId: 'onboard-call',
            variant: InputStepVariant.standalone,
            question: '질문',
            input: SizedBox(key: inputKey, height: 52),
            actionLabel: '다음',
            onAction: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(inputKey)).dy,
        tester.getBottomLeft(find.text('질문')).dy + Space.s24,
      );
    });

    testWidgets('helpStyleOf는 도움말과 같은 글자 스타일입니다', (tester) async {
      late TextStyle shared;
      await tester.pumpWidget(
        inputApp(
          Builder(
            builder: (context) {
              shared = InputStep.helpStyleOf(context);
              return _step(help: '도움말');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('도움말')).style, shared);
    });

    group('맨 아래 버튼 자리(V106)', () {
      /// 아래 시스템 inset [inset](Android 3버튼 48, 제스처 막대, 없음 0, iPhone 34)과
      /// 키보드 [keyboard]를 띄운 400x800 화면.
      void device(
        WidgetTester tester, {
        double inset = 0,
        double keyboard = 0,
      }) {
        tester.view
          ..physicalSize = const Size(400, 800)
          ..devicePixelRatio = 1
          // 기기는 키보드가 열리면 padding(가려진 몫)을 줄여 알립니다(viewPadding은 그대로).
          ..padding = FakeViewPadding(
            bottom: keyboard >= inset ? 0 : inset - keyboard,
          )
          ..viewPadding = FakeViewPadding(bottom: inset)
          ..viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(() {
          tester.view
            ..reset()
            ..resetPadding()
            ..resetViewPadding()
            ..resetViewInsets();
        });
      }

      const skipKey = ValueKey('skip');
      InputStep twoButtons({VoidCallback? onSkip}) => InputStep(
        screenId: 'notify-ask',
        variant: InputStepVariant.standalone,
        question: '알림을 받을까요?',
        input: const SizedBox(height: 52),
        actionLabel: '알림 받기',
        onAction: () {},
        secondaryActionLabel: '나중에',
        secondaryActionKey: skipKey,
        onSecondaryAction: onSkip ?? () {},
      );

      for (final inset in [0.0, 24.0, 34.0, 48.0]) {
        testWidgets('inset $inset: 버튼 아래 끝은 inset 위 space.16입니다', (
          tester,
        ) async {
          device(tester, inset: inset);
          await tester.pumpWidget(inputApp(_step()));
          await tester.pumpAndSettle();
          expect(
            tester.getBottomLeft(find.byType(PrimaryButton)).dy,
            800 - inset - InputStep.bottomGap,
          );
        });

        testWidgets('inset $inset: SafeArea가 inset을 비운 화면에서도 같습니다', (
          tester,
        ) async {
          device(tester, inset: inset);
          await tester.pumpWidget(inputApp(SafeArea(child: _step())));
          await tester.pumpAndSettle();
          expect(
            tester.getBottomLeft(find.byType(PrimaryButton)).dy,
            800 - inset - InputStep.bottomGap,
          );
        });

        testWidgets('inset $inset: 두 번째 버튼이 맨 아래 버튼이고 두 버튼 사이는 space.16입니다', (
          tester,
        ) async {
          device(tester, inset: inset);
          await tester.pumpWidget(inputApp(SafeArea(child: twoButtons())));
          await tester.pumpAndSettle();
          final primary = tester.getRect(
            find.widgetWithText(PrimaryButton, '알림 받기'),
          );
          final skip = tester.getRect(find.byKey(skipKey));
          expect(skip.bottom, 800 - inset - InputStep.bottomGap);
          expect(skip.top - primary.bottom, InputStep.secondaryActionGap);
          expect(primary.height, 52);
          expect(skip.height, 52, reason: '두 버튼 높이 모두 52(V60)');
          expect(skip.left, Space.s20);
          expect(skip.right, 400 - Space.s20);
        });
      }

      testWidgets('키보드가 열리면 inset과 상관없이 두 버튼이 함께 키보드 위 space.16에 붙습니다', (
        tester,
      ) async {
        device(tester, inset: 48, keyboard: 300);
        await tester.pumpWidget(inputApp(SafeArea(child: twoButtons())));
        await tester.pumpAndSettle();
        final primary = tester.getRect(
          find.widgetWithText(PrimaryButton, '알림 받기'),
        );
        final skip = tester.getRect(find.byKey(skipKey));
        expect(skip.bottom, 800 - 300 - InputStep.bottomGap);
        expect(skip.top - primary.bottom, InputStep.secondaryActionGap);
      });

      testWidgets('두 번째 버튼은 quiet이고 누르면 onSecondaryAction, null이면 disabled', (
        tester,
      ) async {
        var skipped = 0;
        await tester.pumpWidget(inputApp(twoButtons(onSkip: () => skipped++)));
        await tester.pumpAndSettle();
        final skip = tester.widget<PrimaryButton>(find.byKey(skipKey));
        expect(skip.variant, PrimaryButtonVariant.quiet);
        await tester.tap(find.byKey(skipKey));
        expect(skipped, 1);

        await tester.pumpWidget(
          inputApp(
            const InputStep(
              screenId: 'notify-ask',
              variant: InputStepVariant.standalone,
              question: '질문',
              input: SizedBox(),
              actionLabel: '알림 받기',
              onAction: null,
              secondaryActionLabel: '나중에',
              secondaryActionKey: skipKey,
            ),
          ),
        );
        expect(
          tester.widget<PrimaryButton>(find.byKey(skipKey)).onPressed,
          isNull,
        );
      });
    });

    testWidgets('글자 3.0배에서도 overflow 없이 스크롤됩니다', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(3),
          ),
          child: inputApp(_step(error: '범위를 벗어났어요', help: '도움말')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
