import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookUseCase _stage(String name, Widget Function() build) =>
    WidgetbookUseCase(
      name: name,
      builder: (context) => Stage(child: build()),
    );

/// 눌러서 고르는 계정 합치기 카드 두 장. 처음에는 고르지 않음(`none`)입니다.
class _AccountChoiceDemo extends StatefulWidget {
  const new({required this.locked, required this.loading});

  /// 고름 잠금(`disabled`, 합치는 중).
  final bool locked;

  /// 불러오는 중(`loading`).
  final bool loading;

  @override
  State<_AccountChoiceDemo> createState() => _AccountChoiceDemoState();
}

class _AccountChoiceDemoState extends State<_AccountChoiceDemo> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 320,
      child: AccountChoice(
        options: [
          AccountChoiceOption(
            name: '달',
            current: true,
            saju: l10n.accountChoiceSaju('1990.04.15', '양력', '오전 7:30'),
          ),
          AccountChoiceOption(
            name: '별',
            current: false,
            saju: l10n.accountChoiceSajuEmpty,
          ),
        ],
        selectedIndex: _selected,
        onSelected: widget.locked
            ? null
            : (index) => setState(() => _selected = index),
        groupLabel: l10n.accountMergeChoiceLabel,
        currentLabel: l10n.accountChoiceCurrent,
        otherLabel: l10n.accountChoiceOther,
        loading: widget.loading,
      ),
    );
  }
}

/// 입력 화면 틀. 높이를 정해야 내용이 스크롤되고 버튼이 아래에 붙습니다.
Widget _inputStep({
  required InputStepVariant variant,
  bool error = false,
  bool loading = false,
}) => SizedBox(
  width: 360,
  height: 560,
  child: InputStep(
    screenId: 'onboard-call',
    variant: variant,
    step: 2,
    stepCount: 4,
    question: '뭐라고 부르면 될까요?',
    input: const MyungliTextField(label: '호칭', hint: '예: 달', maxLength: 10),
    help: '실명이 아니어도 괜찮아요.',
    error: error ? '지원하는 범위를 벗어났어요.' : null,
    actionLabel: '다음',
    actionLoading: loading,
    onAction: () {},
  ),
);

/// 눌러서 바뀌는 segmented. [none]이면 아직 고르지 않은 상태에서 시작합니다.
Widget _segmented(
  List<String> labels, {
  bool disabled = false,
  bool none = false,
}) {
  var selected = none ? null : 0;
  return SizedBox(
    width: 360,
    child: StatefulBuilder(
      builder: (context, setState) => Segmented<int?>(
        label: '고르기',
        items: [
          for (var i = 0; i < labels.length; i++) SegmentedItem(i, labels[i]),
        ],
        selected: selected,
        onChanged: disabled
            ? null
            : (value) => setState(() => selected = value),
      ),
    ),
  );
}

/// 눌러서 켜고 꺼지는 check-row.
Widget _checkRow(
  CheckRowVariant variant, {
  bool initiallyChecked = false,
  bool disabled = false,
}) {
  var checked = initiallyChecked;
  return SizedBox(
    width: 360,
    child: StatefulBuilder(
      builder: (context, setState) => CheckRow(
        variant: variant,
        label: variant == CheckRowVariant.card
            ? '이용약관에 동의합니다 (필수)'
            : '태어난 시간을 몰라요',
        checked: checked,
        onChanged: disabled ? null : (value) => setState(() => checked = value),
        viewLabel: '보기',
        onView: () {},
      ),
    ),
  );
}

/// 달을 넘기고 날을 고르는 date-picker calendar.
class _MonthDatePickerDemo extends StatefulWidget {
  const new({this.disabled = false});

  /// 고른 날 일기를 다 채워 아래 버튼이 꺼진 모양인지(D83 ②).
  final bool disabled;

  @override
  State<_MonthDatePickerDemo> createState() => _MonthDatePickerDemoState();
}

class _MonthDatePickerDemoState extends State<_MonthDatePickerDemo> {
  static final _today = CalendarDate(2026, 10, 13);
  CalendarMonth _month = CalendarMonth.of(_today);
  CalendarDate _selected = _today;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: MonthDatePicker(
      month: _month,
      selected: _selected,
      today: _today,
      markedDates: {CalendarDate(2026, 10, 2), CalendarDate(2026, 10, 12)},
      onSelect: (date) => setState(() => _selected = date),
      onMonthChange: (month) => setState(() => _month = month),
      confirmLabel: widget.disabled
          ? '이날은 충분히 썼어요'
          : '${_selected.month}월 ${_selected.day}일 일기 쓰기',
      onConfirm: widget.disabled ? null : () {},
    ),
  );
}

/// 돌려서 바뀌는 생일 휠.
Widget _datePicker(
  BirthDateValue initial, {
  DatePickerVariant variant = DatePickerVariant.birth,
  int? leapMonth,
  SolarConfirm? solarConfirm,
}) {
  var value = initial;
  return SizedBox(
    width: 360,
    child: StatefulBuilder(
      builder: (context, setState) => BirthDatePicker(
        value: value,
        onChanged: (next) => setState(() => value = next),
        calendarLabelSolar: '양력',
        calendarLabelLunar: '음력',
        leapMonth: leapMonth,
        solarConfirm: solarConfirm,
        variant: variant,
      ),
    ),
  );
}

/// 돌려서 바뀌는 시간 휠.
Widget _timePicker(
  TimePickerVariant variant, {
  bool unknown = false,
  String? sijinConfirm,
}) {
  var value = const TimeOfDay(hour: 7, minute: 30);
  var isUnknown = unknown;
  return SizedBox(
    width: 360,
    child: StatefulBuilder(
      builder: (context, setState) => TimePicker(
        variant: variant,
        value: value,
        onChanged: (next) => setState(() => value = next),
        unknown: isUnknown,
        onUnknownChanged: variant == TimePickerVariant.birth
            ? (next) => setState(() => isUnknown = next)
            : null,
        unknownLabel: variant == TimePickerVariant.birth ? '모름' : null,
        unknownNotice: '시간을 몰라도 풀이할 수 있어요.',
        sijinConfirm: sijinConfirm,
      ),
    ),
  );
}

/// 쳐서 바뀌는 도시 검색. 글자에 맞는 도시만 걸러 보이고 비면 빈 상태입니다.
/// [saving]이면 줄을 누르는 순간 그 줄이 저장 중(끝에 점)이 되고 다른 줄은 눌리지 않습니다.
Widget _citySearch({bool loading = false, bool saving = false}) {
  final cities = [
    City(
      id: '1835848',
      name: 'Seoul',
      country: 'KR',
      countryName: 'South Korea',
      timezone: 'Asia/Seoul',
      longitude: 126.9780,
    ),
    City(
      id: '1838524',
      name: 'Busan',
      country: 'KR',
      countryName: 'South Korea',
      regionName: 'Busan',
      timezone: 'Asia/Seoul',
      longitude: 129.0756,
    ),
    City(
      id: '5391959',
      name: 'San Francisco',
      country: 'US',
      countryName: 'United States',
      regionName: 'California',
      timezone: 'America/Los_Angeles',
      longitude: -122.4194,
    ),
    City(
      id: '2643743',
      name: 'London',
      country: 'GB',
      countryName: 'United Kingdom',
      regionName: 'England',
      timezone: 'Europe/London',
      longitude: -0.1276,
    ),
  ];
  AsyncValue<List<City>>? results;
  String? savingId;
  return SizedBox(
    width: 360,
    child: StatefulBuilder(
      builder: (context, setState) => CitySearch(
        label: '도시 이름',
        hint: '예: Seoul',
        onQueryChanged: (query) => setState(() {
          final needle = query.trim().toLowerCase();
          results = needle.isEmpty
              ? null
              : loading
              ? const AsyncLoading()
              : AsyncData([
                  for (final city in cities)
                    if (city.name.toLowerCase().contains(needle)) city,
                ]);
        }),
        results: results,
        savingCityId: saving ? savingId : null,
        onSelected: (city) => setState(() => savingId = city.id),
        emptyBody: '찾는 도시가 없어요.',
        onRetry: () {},
      ),
    ),
  );
}

/// 입력 카탈로그: input-step, text-field, segmented, check-row,
/// date-picker, time-picker, account-choice, city-search.
final WidgetbookFolder inputDirectory = WidgetbookFolder(
  name: '입력',
  children: [
    WidgetbookComponent(
      name: 'input-step',
      useCases: [
        _stage(
          'onboarding(valid)',
          () => _inputStep(variant: InputStepVariant.onboarding),
        ),
        _stage(
          'onboarding(out-of-range)',
          () => _inputStep(variant: InputStepVariant.onboarding, error: true),
        ),
        _stage(
          'standalone',
          () => _inputStep(variant: InputStepVariant.standalone),
        ),
        _stage(
          'onboarding(버튼 loading)',
          () => _inputStep(variant: InputStepVariant.onboarding, loading: true),
        ),
        _stage(
          '고르면 바로 넘어감(아래 버튼 없음)',
          () => SizedBox(
            width: 360,
            height: 560,
            child: InputStep.selectToAdvance(
              screenId: 'birthplace',
              variant: InputStepVariant.onboarding,
              step: 5,
              stepCount: 5,
              question: '어디서 태어났나요?',
              input: _citySearch(),
              help: '태어난 곳의 시간대로 계산해요.',
            ),
          ),
        ),
        _stage(
          '머리말(preface) + 계산 기준 링크',
          () => SizedBox(
            width: 360,
            height: 560,
            child: Builder(
              builder: (context) => InputStep.selectToAdvance(
                screenId: 'birthplace',
                variant: InputStepVariant.onboarding,
                step: 5,
                stepCount: 5,
                question: '어디서 태어났나요?',
                preface: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '명리일기는 한국에서 널리 쓰는 기준으로 계산해요.',
                      style: InputStep.helpStyleOf(context),
                    ),
                    DepthLink(
                      variant: DepthLinkVariant.navigate,
                      label: '계산 기준 보기',
                      onTap: () {},
                    ),
                  ],
                ),
                input: _citySearch(),
                help: '태어난 곳의 시간대로 계산해요.',
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'text-field',
      useCases: [
        _stage(
          '기본(눌러서 포커스)',
          () => const SizedBox(
            width: 360,
            child: MyungliTextField(label: '호칭', hint: '예: 달', maxLength: 10),
          ),
        ),
        _stage(
          'error',
          () => const SizedBox(
            width: 360,
            child: MyungliTextField(label: '호칭', error: true),
          ),
        ),
        _stage(
          'disabled',
          () => const SizedBox(
            width: 360,
            child: MyungliTextField(label: '호칭', enabled: false),
          ),
        ),
        _stage(
          '여러 줄(메모, 6줄까지 늘어남)',
          () => const SizedBox(
            width: 360,
            child: MyungliTextField(
              label: '메모',
              hint: '메모',
              maxLength: 2000,
              maxLines: MyungliTextField.maxLinesLimit,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'segmented',
      useCases: [
        _stage('2개', () => _segmented(['양력', '음력'])),
        _stage('3개', () => _segmented(['여성', '남성', '선택 안 함'])),
        _stage('4개', () => _segmented(['1:1', '4:5', '9:16', '16:9'])),
        _stage('disabled', () => _segmented(['여성', '남성'], disabled: true)),
        _stage(
          'none · 처음 고르면 스며 나타남',
          () => _segmented(['여성', '남성'], none: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'check-row',
      useCases: [
        _stage('card', () => _checkRow(CheckRowVariant.card)),
        _stage(
          'card(checked)',
          () => _checkRow(CheckRowVariant.card, initiallyChecked: true),
        ),
        _stage(
          'card(disabled)',
          () => _checkRow(CheckRowVariant.card, disabled: true),
        ),
        _stage('inline', () => _checkRow(CheckRowVariant.inline)),
      ],
    ),
    WidgetbookComponent(
      name: 'date-picker',
      useCases: [
        _stage(
          'birth(양력)',
          () => _datePicker(
            const BirthDateValue(
              calendar: BirthCalendar.solar,
              year: 1990,
              month: 3,
              day: 15,
            ),
          ),
        ),
        _stage(
          'birth(음력, 윤2월 칸·확인 줄)',
          () => _datePicker(
            const BirthDateValue(
              calendar: BirthCalendar.lunar,
              year: 2023,
              month: 2,
              day: 29,
              isLeapMonth: true,
            ),
            leapMonth: 2,
            solarConfirm: const SolarConfirm.text('양력 2023년 4월 19일'),
          ),
        ),
        _stage(
          'birth(음력, 확인 조회 중)',
          () => _datePicker(
            const BirthDateValue(
              calendar: BirthCalendar.lunar,
              year: 1990,
              month: 4,
              day: 15,
            ),
            solarConfirm: const SolarConfirm.loading(),
          ),
        ),
        WidgetbookUseCase(
          name: 'calendar(일기 날짜)',
          builder: (context) => Stage(
            child: _MonthDatePickerDemo(
              disabled: context.knobs.boolean(label: '비활성(고른 날 다 채움)'),
            ),
          ),
        ),
        _stage(
          'solar(일정 날짜)',
          () => _datePicker(
            const BirthDateValue(
              calendar: BirthCalendar.solar,
              year: 2026,
              month: 10,
              day: 16,
            ),
            variant: DatePickerVariant.solar,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'time-picker',
      useCases: [
        _stage(
          'birth(시진 확인 줄)',
          () => _timePicker(
            TimePickerVariant.birth,
            sijinConfirm: '사시 (09:30~11:30)',
          ),
        ),
        _stage('birth(확인 줄 없음)', () => _timePicker(TimePickerVariant.birth)),
        _stage(
          'birth(모름)',
          () => _timePicker(TimePickerVariant.birth, unknown: true),
        ),
        _stage('notify(5분 단위)', () => _timePicker(TimePickerVariant.notify)),
      ],
    ),
    WidgetbookComponent(
      name: 'account-choice',
      useCases: [
        WidgetbookUseCase(
          name: '고르기(none → selected)',
          builder: (context) => Stage(
            child: _AccountChoiceDemo(
              locked: context.knobs.boolean(label: '고름 잠금(disabled)'),
              loading: context.knobs.boolean(label: 'loading'),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'city-search',
      useCases: [
        _stage('쳐서 걸러짐(예: s, lon, zzz)', _citySearch),
        _stage('loading(아무 글자)', () => _citySearch(loading: true)),
        _stage('saving(글자를 치고 줄을 누름)', () => _citySearch(saving: true)),
      ],
    ),
  ],
);
