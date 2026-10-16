import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
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

/// input-step 머리말(preface): birthplace처럼 질문과 입력 사이에 소개 글과
/// 계산 기준 링크(`depth-link` `navigate`)를 둔 고르면 바로 넘어가는 단계.
Widget _inputStepPreface() => Builder(
  builder: (context) {
    final ja = _ja(context);
    return SizedBox(
      height: 460,
      child: InputStep.selectToAdvance(
        screenId: 'birthplace',
        variant: InputStepVariant.onboarding,
        step: 5,
        stepCount: 5,
        question: ja ? 'どこで生まれましたか?' : '어디서 태어났나요?',
        preface: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ja ? '命理日記は、韓国で広く使われている基準で計算します。' : '명리일기는 한국에서 널리 쓰는 기준으로 계산해요.',
              style: InputStep.helpStyleOf(context),
            ),
            DepthLink(
              variant: DepthLinkVariant.navigate,
              label: ja ? '計算の基準を見る' : '계산 기준 보기',
              onTap: () {},
            ),
          ],
        ),
        input: CitySearch(
          label: ja ? '都市名' : '도시 이름',
          hint: ja ? '例: ソウル' : '예: Seoul',
          onQueryChanged: (_) {},
          results: null,
          onSelected: (_) {},
          emptyBody: ja ? '見つかる都市がありません。' : '찾는 도시가 없어요.',
          onRetry: () {},
          animated: false,
        ),
        help: ja ? '生まれた場所のタイムゾーンで計算します。' : '태어난 곳의 시간대로 계산해요.',
      ),
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
          controller: TextEditingController(text: ja ? 'ツキツキツキ' : '달이달이달이'),
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

/// segmented: 2개·3개·4개, 처음·끝 선택, disabled, none.
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
            SegmentedItem(2, ja ? '他' : '기타'),
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
        // none: 아직 고르지 않음(표시 막대 없음, 글자 모두 text.secondary).
        Segmented<int?>(
          label: '성별',
          items: [
            SegmentedItem(0, ja ? '女性' : '여성'),
            SegmentedItem(1, ja ? '男性' : '남성'),
          ],
          selected: null,
          onChanged: (_) {},
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

/// date-picker: 양력 / 음력 + 윤달 체크.
Widget _datePickers() => Builder(
  builder: (context) {
    final ja = _ja(context);
    Widget picker(BirthDateValue value) => BirthDatePicker(
      value: value,
      onChanged: (_) {},
      calendarLabelSolar: ja ? '新暦' : '양력',
      calendarLabelLunar: ja ? '旧暦' : '음력',
      leapMonthLabel: ja ? '閏月' : '윤달',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s16,
      children: [
        picker(
          const BirthDateValue(
            calendar: BirthCalendar.solar,
            year: 1990,
            month: 3,
            day: 15,
          ),
        ),
        picker(
          const BirthDateValue(
            calendar: BirthCalendar.lunar,
            year: 2023,
            month: 2,
            day: 30,
            isLeapMonth: true,
          ),
        ),
      ],
    );
  },
);

/// time-picker: birth(시진 확인 줄)·birth(확인 줄 없음)·birth(모름)·notify.
Widget _timePickers() => Builder(
  builder: (context) {
    final ja = _ja(context);
    Widget birth({bool unknown = false, String? sijin}) => TimePicker(
      variant: TimePickerVariant.birth,
      value: const TimeOfDay(hour: 10, minute: 30),
      onChanged: (_) {},
      unknown: unknown,
      onUnknownChanged: (_) {},
      unknownLabel: ja ? '時間は分からない' : '태어난 시간을 몰라요',
      unknownNotice: ja ? '時間が分からなくても大丈夫です。' : '시간을 몰라도 괜찮아요.',
      sijinConfirm: sijin,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s16,
      children: [
        birth(sijin: ja ? '巳の刻(09:30~11:30)' : '사시 (09:30~11:30)'),
        birth(),
        birth(unknown: true),
        TimePicker(
          variant: TimePickerVariant.notify,
          value: const TimeOfDay(hour: 8, minute: 0),
          onChanged: (_) {},
        ),
      ],
    );
  },
);

/// city-search: 결과 있음·loading·빈 목록·오류.
Widget _citySearches() => Builder(
  builder: (context) {
    final ja = _ja(context);
    Widget search(AsyncValue<List<City>>? results) => CitySearch(
      label: ja ? '都市名' : '도시 이름',
      hint: ja ? '例: ソウル' : '예: Seoul',
      onQueryChanged: (_) {},
      results: results,
      onSelected: (_) {},
      emptyBody: ja ? '見つかる都市がありません。' : '찾는 도시가 없어요.',
      onRetry: () {},
      skeletonDelay: Duration.zero,
      animated: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s24,
      children: [
        search(null),
        search(
          AsyncData([
            City(
              id: '1',
              name: 'Seoul',
              country: 'KR',
              countryName: 'South Korea',
              timezone: 'Asia/Seoul',
            ),
            City(
              id: '2',
              name: 'Busan',
              country: 'KR',
              countryName: 'South Korea',
              regionName: 'Busan',
              timezone: 'Asia/Seoul',
            ),
            City(
              id: '3',
              name: 'San Francisco',
              country: 'US',
              countryName: 'United States',
              regionName: 'California',
              timezone: 'America/Los_Angeles',
            ),
          ]),
        ),
        search(const AsyncLoading()),
        search(const AsyncData([])),
        search(const AsyncError<List<City>>(OfflineError(), StackTrace.empty)),
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

  goldenTest('input-step: 머리말(preface) + depth-link navigate', (tester) async {
    await goldenMatrix(
      tester,
      'input_input_step_preface',
      _inputStepPreface,
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

  goldenTest('date-picker(birth): 양력·음력+윤달 체크', (tester) async {
    await goldenMatrix(
      tester,
      'input_date_picker',
      _datePickers,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('time-picker: birth(확인 줄·없음·모름)·notify', (tester) async {
    await goldenMatrix(
      tester,
      'input_time_picker',
      _timePickers,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('city-search: 비었음·결과·loading·빈 목록·오류', (tester) async {
    await goldenMatrix(
      tester,
      'input_city_search',
      _citySearches,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });
}
