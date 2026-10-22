import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

import 'input_harness.dart';

const List<AccountChoiceOption> _options = [
  AccountChoiceOption(
    name: '달',
    current: true,
    saju: '양력 1990.04.15 오전 7:30',
    diaryCount: '일기 12편',
    providers: '카카오 · Apple',
  ),
  AccountChoiceOption(
    name: '별',
    current: false,
    saju: '사주 정보 없음',
    diaryCount: '일기 3편',
    providers: 'LINE',
  ),
];

Widget _choice({
  int? selectedIndex,
  ValueChanged<int>? onSelected,
  bool loading = false,
}) => Padding(
  padding: const EdgeInsets.all(20),
  child: AccountChoice(
    options: _options,
    selectedIndex: selectedIndex,
    onSelected: onSelected,
    groupLabel: '남길 계정을 골라 주세요',
    currentLabel: '현재 계정',
    loading: loading,
    animated: false,
  ),
);

/// 두 카드의 스크린리더 라벨(카드 안 글자를 위에서 아래로).
const String _firstLabel =
    '달, 현재 계정, 양력 1990.04.15 오전 7:30, 일기 12편, 카카오 · Apple';
const String _secondLabel = '별, 사주 정보 없음, 일기 3편, LINE';

void main() {
  group('account-choice', () {
    CheckedState checked(WidgetTester tester, String label) => tester
        .getSemantics(find.bySemanticsLabel(label))
        .getSemanticsData()
        .flagsCollection
        .isChecked;

    testWidgets('처음에는 어느 카드도 고르지 않습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_choice(onSelected: (_) {})));
      expect(checked(tester, _firstLabel), CheckedState.isFalse);
      expect(checked(tester, _secondLabel), CheckedState.isFalse);
      expect(find.byKey(AccountChoice.dotKey(0)), findsNothing);
      expect(find.byKey(AccountChoice.dotKey(1)), findsNothing);
      handle.dispose();
    });

    testWidgets('카드를 누르면 onSelected(그 index)와 selection 햅틱입니다', (tester) async {
      final haptics = recordHaptics(tester);
      final chosen = <int>[];
      await tester.pumpWidget(inputApp(_choice(onSelected: chosen.add)));
      await tester.tap(find.text('별'));
      await tester.pumpAndSettle();
      expect(chosen, [1]);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('이미 고른 카드를 다시 누르면 아무 일도 없습니다', (tester) async {
      final chosen = <int>[];
      await tester.pumpWidget(
        inputApp(_choice(selectedIndex: 0, onSelected: chosen.add)),
      );
      await tester.tap(find.text('달'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);
    });

    testWidgets('고른 카드는 checked이고 action.primary 테두리와 점이 보입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        inputApp(_choice(selectedIndex: 1, onSelected: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(checked(tester, _firstLabel), CheckedState.isFalse);
      expect(checked(tester, _secondLabel), CheckedState.isTrue);
      expect(find.byKey(AccountChoice.dotKey(1)), findsOneWidget);
      expect(find.byKey(AccountChoice.dotKey(0)), findsNothing);
      final primary = tester
          .element(find.byType(AccountChoice))
          .tokens
          .colors
          .actionPrimary;
      final border =
          (tester
                      .widget<DecoratedBox>(
                        find.byKey(AccountChoice.selectedBorderKey(1)),
                      )
                      .decoration
                  as BoxDecoration)
              .border!
              .top;
      expect(border.color, primary);
      expect(border.width, AccountChoice.cardBorderWidth);
      handle.dispose();
    });

    testWidgets('onSelected가 null이면 눌러도 바뀌지 않고 모양은 그대로입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_choice(selectedIndex: 0)));
      await tester.tap(find.text('별'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(checked(tester, _firstLabel), CheckedState.isTrue);
      final data = tester
          .getSemantics(find.bySemanticsLabel(_secondLabel))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      // 흐리지 않습니다(고른 표시의 스밈이 끝난 Opacity 1은 그대로).
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('radio-group 이름은 groupLabel, 카드 라벨은 카드 안 글자를 위에서 아래로', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inputApp(_choice(onSelected: (_) {})));
      final group = tester
          .getSemantics(find.bySemanticsLabel('남길 계정을 골라 주세요'))
          .getSemanticsData();
      expect(group.role, SemanticsRole.radioGroup);
      for (final label in [_firstLabel, _secondLabel]) {
        final card = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(
          card.flagsCollection.isInMutuallyExclusiveGroup,
          isTrue,
          reason: label,
        );
        expect(card.hasAction(SemanticsAction.tap), isTrue, reason: label);
      }
      handle.dispose();
    });

    testWidgets('current 카드에만 currentLabel 알약이 있습니다', (tester) async {
      await tester.pumpWidget(inputApp(_choice(onSelected: (_) {})));
      expect(find.text('현재 계정'), findsOneWidget);
      final pill = find.ancestor(
        of: find.text('현재 계정'),
        matching: find.byKey(AccountChoice.currentPillKey),
      );
      expect(pill, findsOneWidget);
      // 알약은 첫 카드(current: true)의 호칭 줄에 있습니다.
      expect(
        tester.getCenter(find.text('현재 계정')).dy,
        moreOrLessEquals(tester.getCenter(find.text('달')).dy, epsilon: 2),
      );
    });

    testWidgets('loading이면 카드 글자가 없고 카드 두 장 자리가 숨쉽니다', (tester) async {
      await tester.pumpWidget(inputApp(_choice(loading: true)));
      expect(find.text('달'), findsNothing);
      expect(find.text('별'), findsNothing);
      expect(find.byKey(AccountChoice.loadingCardKey(0)), findsOneWidget);
      expect(find.byKey(AccountChoice.loadingCardKey(1)), findsOneWidget);
    });

    testWidgets('options가 두 개가 아니면 assert입니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          AccountChoice(
            options: _options.sublist(0, 1),
            selectedIndex: null,
            onSelected: null,
            groupLabel: 'x',
            currentLabel: 'y',
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });
}
