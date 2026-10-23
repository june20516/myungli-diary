import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/month_date_picker.dart';
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
    // 2.0배에서도 맨 아래 도움말 줄까지 보이는 높이입니다.
    return SizedBox(
      height: 560,
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

/// text-field 여러 줄(#218 ⑤, event-edit 메모): 비었음(최소 높이 52)·세 줄·상한 6줄을 넘음.
Widget _multilineFields() => Builder(
  builder: (context) {
    final ja = _ja(context);
    final line = ja ? '持ち物' : '챙길 것';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        MyungliTextField(
          label: '메모',
          hint: ja ? 'メモ' : '메모',
          maxLength: 2000,
          maxLines: MyungliTextField.maxLinesLimit,
        ),
        MyungliTextField(
          label: '메모',
          maxLength: 2000,
          maxLines: MyungliTextField.maxLinesLimit,
          controller: TextEditingController(
            text: [for (var i = 1; i <= 3; i++) '$line $i'].join('\n'),
          ),
        ),
        MyungliTextField(
          label: '메모',
          maxLength: 2000,
          maxLines: MyungliTextField.maxLinesLimit,
          controller: TextEditingController(
            text: [for (var i = 1; i <= 8; i++) '$line $i'].join('\n'),
          ),
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

/// date-picker: 양력 / 음력(V31 목표 모양: 윤2월 칸 + 양력 확인 줄). 조회 중 skeleton은 숨쉬기가
/// 끝나지 않아 위젯 테스트가 확인합니다.
Widget _datePickers() => Builder(
  builder: (context) {
    final ja = _ja(context);
    Widget picker(
      BirthDateValue value, {
      int? leapMonth,
      SolarConfirm? solarConfirm,
    }) => BirthDatePicker(
      value: value,
      onChanged: (_) {},
      calendarLabelSolar: ja ? '新暦' : '양력',
      calendarLabelLunar: ja ? '旧暦' : '음력',
      leapMonth: leapMonth,
      solarConfirm: solarConfirm,
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
            day: 29,
            isLeapMonth: true,
          ),
          leapMonth: 2,
          solarConfirm: SolarConfirm.text(
            ja ? '新暦 2023年4月19日' : '양력 2023년 4월 19일',
          ),
        ),
      ],
    );
  },
);

/// date-picker: solar(일정 날짜) — 양력·음력 선택과 윤달 줄이 없습니다.
Widget _solarOnlyDatePicker() => BirthDatePicker(
  value: const BirthDateValue(
    calendar: BirthCalendar.solar,
    year: 2026,
    month: 10,
    day: 16,
  ),
  onChanged: (_) {},
  calendarLabelSolar: '양력',
  calendarLabelLunar: '음력',
  variant: DatePickerVariant.solar,
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
              longitude: 126.9780,
            ),
            City(
              id: '2',
              name: 'Busan',
              country: 'KR',
              countryName: 'South Korea',
              regionName: 'Busan',
              timezone: 'Asia/Seoul',
              longitude: 129.0756,
            ),
            City(
              id: '3',
              name: 'San Francisco',
              country: 'US',
              countryName: 'United States',
              regionName: 'California',
              timezone: 'America/Los_Angeles',
              longitude: -122.4194,
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

/// city-search saving: 고른 줄 끝에 점(정지), 다른 줄은 눌림 없이 그대로.
Widget _citySearchSaving() => Builder(
  builder: (context) {
    final ja = _ja(context);
    final seoul = City(
      id: '1',
      name: 'Seoul',
      country: 'KR',
      countryName: 'South Korea',
      timezone: 'Asia/Seoul',
      longitude: 126.9780,
    );
    final busan = City(
      id: '2',
      name: 'Busan',
      country: 'KR',
      countryName: 'South Korea',
      regionName: 'Busan',
      timezone: 'Asia/Seoul',
      longitude: 129.0756,
    );
    return CitySearch(
      label: ja ? '都市名' : '도시 이름',
      hint: ja ? '例: ソウル' : '예: Seoul',
      onQueryChanged: (_) {},
      results: AsyncData([seoul, busan]),
      onSelected: (_) {},
      emptyBody: ja ? '見つかる都市がありません。' : '찾는 도시가 없어요.',
      onRetry: () {},
      savingCityId: seoul.id,
      skeletonDelay: Duration.zero,
      animated: false,
    );
  },
);

/// date-picker calendar: 일기 쓴 날 도장, 오늘·선택, 미래 막힘, 아래 버튼.
Widget _monthDatePicker() => Builder(
  builder: (context) => MonthDatePicker(
    month: const CalendarMonth(2026, 10),
    selected: CalendarDate(2026, 10, 8),
    today: CalendarDate(2026, 10, 13),
    markedDates: {CalendarDate(2026, 10, 2), CalendarDate(2026, 10, 12)},
    onSelect: (_) {},
    onMonthChange: (_) {},
    confirmLabel: AppLocalizations.of(context).diaryListPickDateConfirm(
      Localizations.localeOf(context).languageCode == 'ja' ? '10月8日' : '10월 8일',
    ),
    onConfirm: () {},
  ),
);

/// account-choice: none(처음)·selected(둘째 카드)·disabled(고름 잠금)·loading.
Widget _accountChoices() => Builder(
  builder: (context) {
    final ja = _ja(context);
    final l10n = AppLocalizations.of(context);
    final options = [
      AccountChoiceOption(
        name: ja ? 'つき' : '달',
        current: true,
        saju: l10n.accountChoiceSaju(
          '1990.04.15',
          ja ? '陽暦' : '양력',
          ja ? '午前7:30' : '오전 7:30',
        ),
      ),
      AccountChoiceOption(
        name: ja ? 'ほし' : '별',
        current: false,
        saju: l10n.accountChoiceSajuEmpty,
      ),
    ];
    AccountChoice choice({
      int? selectedIndex,
      bool locked = false,
      bool loading = false,
    }) => AccountChoice(
      options: options,
      selectedIndex: selectedIndex,
      onSelected: locked ? null : (_) {},
      groupLabel: l10n.accountMergeChoiceLabel,
      currentLabel: l10n.accountChoiceCurrent,
      otherLabel: l10n.accountChoiceOther,
      loading: loading,
      animated: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s24,
      children: [
        choice(),
        choice(selectedIndex: 1),
        choice(selectedIndex: 0, locked: true),
        choice(loading: true),
      ],
    );
  },
);

void main() {
  goldenTest('date-picker: calendar', (tester) async {
    await goldenMatrix(tester, 'input_month_date_picker', _monthDatePicker);
  });

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

  goldenTest('text-field: 여러 줄(비었음·세 줄·6줄 상한)', (tester) async {
    await goldenMatrix(tester, 'input_text_field_multiline', _multilineFields);
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

  goldenTest('date-picker(birth): 양력·음력(윤달 칸·양력 확인 줄)', (tester) async {
    await goldenMatrix(
      tester,
      'input_date_picker',
      _datePickers,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('date-picker(birth): 양력 전용', (tester) async {
    await goldenMatrix(
      tester,
      'input_date_picker_solar_only',
      _solarOnlyDatePicker,
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

  goldenTest('city-search: saving(고른 줄 점·다른 줄 눌림 없음)', (tester) async {
    await goldenMatrix(
      tester,
      'input_city_search_saving',
      _citySearchSaving,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('account-choice: none·selected·disabled·loading', (tester) async {
    await goldenMatrix(
      tester,
      'input_account_choice',
      _accountChoices,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });
}
