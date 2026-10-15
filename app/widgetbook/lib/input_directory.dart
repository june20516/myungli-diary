import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookUseCase _stage(String name, Widget Function() build) =>
    WidgetbookUseCase(
      name: name,
      builder: (context) => Stage(child: build()),
    );

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

/// 눌러서 바뀌는 segmented.
Widget _segmented(List<String> labels, {bool disabled = false}) {
  var selected = 0;
  return SizedBox(
    width: 360,
    child: StatefulBuilder(
      builder: (context, setState) => Segmented<int>(
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

/// 돌려서 바뀌는 생일 휠.
Widget _datePicker(BirthDateValue initial) {
  var value = initial;
  return SizedBox(
    width: 360,
    child: StatefulBuilder(
      builder: (context, setState) => BirthDatePicker(
        value: value,
        onChanged: (next) => setState(() => value = next),
        calendarLabelSolar: '양력',
        calendarLabelLunar: '음력',
        leapMonthLabel: '윤달',
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
Widget _citySearch({bool loading = false}) {
  final cities = [
    City(
      id: '1835848',
      name: 'Seoul',
      country: 'KR',
      countryName: 'South Korea',
      timezone: 'Asia/Seoul',
    ),
    City(
      id: '1838524',
      name: 'Busan',
      country: 'KR',
      countryName: 'South Korea',
      timezone: 'Asia/Seoul',
    ),
    City(
      id: '5391959',
      name: 'San Francisco',
      country: 'US',
      countryName: 'United States',
      timezone: 'America/Los_Angeles',
    ),
    City(
      id: '2643743',
      name: 'London',
      country: 'GB',
      countryName: 'United Kingdom',
      timezone: 'Europe/London',
    ),
  ];
  AsyncValue<List<City>>? results;
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
        onSelected: (_) {},
        emptyBody: '찾는 도시가 없어요.',
        onRetry: () {},
      ),
    ),
  );
}

/// 입력 카탈로그: input-step, text-field, segmented, check-row,
/// date-picker, time-picker, city-search.
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
      ],
    ),
    WidgetbookComponent(
      name: 'segmented',
      useCases: [
        _stage('2개', () => _segmented(['양력', '음력'])),
        _stage('3개', () => _segmented(['여성', '남성', '선택 안 함'])),
        _stage('4개', () => _segmented(['1:1', '4:5', '9:16', '16:9'])),
        _stage('disabled', () => _segmented(['여성', '남성'], disabled: true)),
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
          'birth(음력, 윤달 체크)',
          () => _datePicker(
            const BirthDateValue(
              calendar: BirthCalendar.lunar,
              year: 2023,
              month: 2,
              day: 30,
              isLeapMonth: true,
            ),
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
      name: 'city-search',
      useCases: [
        _stage('쳐서 걸러짐(예: s, lon, zzz)', _citySearch),
        _stage('loading(아무 글자)', () => _citySearch(loading: true)),
      ],
    ),
  ],
);
