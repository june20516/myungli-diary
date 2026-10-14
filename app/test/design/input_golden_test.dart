import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

bool _ja(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja';

/// input-step: 온보딩(valid, 진행 막대) + standalone(out-of-range, 버튼 disabled).
Widget _inputSteps() => Builder(
  builder: (context) {
    final ja = _ja(context);
    return Column(
      spacing: Space.s16,
      children: [
        SizedBox(
          height: 460,
          child: InputStep(
            screenId: 'onboard-call',
            variant: InputStepVariant.onboarding,
            step: 1,
            stepCount: 4,
            question: ja ? '何と呼べばいいですか?' : '뭐라고 부르면 될까요?',
            input: MyungliTextField(label: ja ? '呼び名' : '호칭', hint: '예: 달'),
            help: ja ? '本名でなくてもかまいません。' : '실명이 아니어도 괜찮아요.',
            actionLabel: ja ? '次へ' : '다음',
            onAction: () {},
          ),
        ),
        SizedBox(
          height: 460,
          child: InputStep(
            screenId: 'onboard-birth',
            variant: InputStepVariant.standalone,
            question: ja ? '生まれた日は?' : '태어난 날은 언제인가요?',
            input: MyungliTextField(label: ja ? '生年月日' : '생년월일', error: true),
            error: ja ? '対応していない日付です。' : '지원하는 범위를 벗어난 날짜예요.',
            actionLabel: ja ? '次へ' : '다음',
            onAction: () {},
          ),
        ),
      ],
    );
  },
);

/// text-field: 비었음(hint)·글자 있음(counter)·error·disabled.
Widget _textFields() => Builder(
  builder: (context) {
    final ja = _ja(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        MyungliTextField(
          label: '호칭',
          hint: ja ? '例: ツキ' : '예: 달',
          maxLength: 10,
        ),
        MyungliTextField(
          label: '호칭',
          maxLength: 10,
          controller: TextEditingController(text: ja ? 'ツキ' : '달이'),
        ),
        MyungliTextField(
          label: '호칭',
          error: true,
          controller: TextEditingController(text: ja ? 'ツキ😀' : '달이😀'),
        ),
        MyungliTextField(
          label: '호칭',
          enabled: false,
          controller: TextEditingController(text: ja ? 'ツキ' : '달이'),
        ),
      ],
    );
  },
);

/// text-field focused: 글자가 있고 포커스가 있어 지우기 아이콘이 보입니다.
///
/// 포커스를 받은 입력칸은 Overlay(선택 손잡이용)가 필요해 직접 둡니다.
Widget _focusedField() => Builder(
  builder: (context) => SizedBox(
    height: 96,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (_) => Align(
            alignment: Alignment.topCenter,
            child: MyungliTextField(
              label: '호칭',
              controller: TextEditingController(
                text: _ja(context) ? 'ツキ' : '달이',
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);

/// segmented: 2개·3개·4개, 처음·끝 선택, disabled.
Widget _segmenteds() => Builder(
  builder: (context) {
    final ja = _ja(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        Segmented<int>(
          label: '양력 음력',
          items: [
            SegmentedItem(0, ja ? '新暦' : '양력'),
            SegmentedItem(1, ja ? '旧暦' : '음력'),
          ],
          selected: 0,
          onChanged: (_) {},
        ),
        Segmented<int>(
          label: '성별',
          items: [
            SegmentedItem(0, ja ? '女性' : '여성'),
            SegmentedItem(1, ja ? '男性' : '남성'),
            SegmentedItem(2, ja ? '答えない' : '선택 안 함'),
          ],
          selected: 2,
          onChanged: (_) {},
        ),
        Segmented<int>(
          label: '비율',
          items: const [
            SegmentedItem(0, '1:1'),
            SegmentedItem(1, '4:5'),
            SegmentedItem(2, '9:16'),
            SegmentedItem(3, '16:9'),
          ],
          selected: 1,
          onChanged: (_) {},
        ),
        Segmented<int>(
          label: '성별',
          items: [
            SegmentedItem(0, ja ? '女性' : '여성'),
            SegmentedItem(1, ja ? '男性' : '남성'),
          ],
          selected: 1,
          onChanged: null,
        ),
      ],
    );
  },
);

/// check-row: card(미체크·체크+보기·disabled·긴 글), inline(미체크·체크).
Widget _checkRows() => Builder(
  builder: (context) {
    final ja = _ja(context);
    final view = ja ? '見る' : '보기';
    final terms = ja ? '利用規約に同意します(必須)' : '이용약관에 동의합니다 (필수)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckRow(
          variant: CheckRowVariant.card,
          label: terms,
          checked: false,
          onChanged: (_) {},
          viewLabel: view,
          onView: () {},
        ),
        CheckRow(
          variant: CheckRowVariant.card,
          label: ja ? '個人情報の収集と利用に同意します(必須)' : '개인정보 수집·이용에 동의합니다 (필수)',
          checked: true,
          onChanged: (_) {},
          viewLabel: view,
          onView: () {},
        ),
        CheckRow(
          variant: CheckRowVariant.card,
          label: terms,
          checked: true,
          onChanged: null,
          viewLabel: view,
          onView: () {},
        ),
        CheckRow(
          variant: CheckRowVariant.card,
          label: ja
              ? 'とても長い同意項目の名前が二行以上に折り返されても、チェックボックスと「見る」が崩れないことを確かめます'
              : '아주 긴 동의 항목 이름이 두 줄 이상으로 접혀도 체크 상자와 보기 링크가 흐트러지지 않는지 확인합니다',
          checked: false,
          onChanged: (_) {},
          viewLabel: view,
          onView: () {},
        ),
        CheckRow(
          variant: CheckRowVariant.inline,
          label: ja ? '時間は分からない' : '태어난 시간을 몰라요',
          checked: false,
          onChanged: (_) {},
        ),
        CheckRow(
          variant: CheckRowVariant.inline,
          label: ja ? '時間は分からない' : '태어난 시간을 몰라요',
          checked: true,
          onChanged: (_) {},
        ),
      ],
    );
  },
);

void main() {
  goldenTest('input-step: onboarding(valid)·standalone(out-of-range)', (
    tester,
  ) async {
    await goldenMatrix(
      tester,
      'input_input_step',
      _inputSteps,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('text-field: 비었음·글자 있음·error·disabled', (tester) async {
    await goldenMatrix(tester, 'input_text_field', _textFields);
  });

  goldenTest('text-field: focused(dark ko 1.0 칸 하나만 포커스)', (tester) async {
    await goldenMatrix(
      tester,
      'input_text_field_focused',
      _focusedField,
      settle: (tester) async {
        // 포커스는 화면에 하나뿐이라 12칸 중 어두운 ko 1.0 칸(여섯 번째)만 받습니다.
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        fields.elementAt(6).focusNode!.requestFocus();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });

  goldenTest('segmented: 2·3·4개, 처음·끝 선택, disabled', (tester) async {
    await goldenMatrix(tester, 'input_segmented', _segmenteds);
  });

  goldenTest('check-row: card·inline × 미체크·체크·disabled', (tester) async {
    await goldenMatrix(
      tester,
      'input_check_row',
      _checkRows,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });
}
