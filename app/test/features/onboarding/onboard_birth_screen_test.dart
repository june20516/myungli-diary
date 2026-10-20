import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/wheel.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_birth_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../../support/app_harness.dart';

final _ko = AppLocalizationsKo();

/// `convertLunarDate` 대역. 2023년만 윤2월이 있고(실제 KASI와 같음), 음력 3월 30일은 없는
/// 날(422 `date.invalid`)입니다. 양력 날짜는 음력 달·일과 윤달에서 정해지는 꾸민 값입니다.
/// [offline]이면 연결 오류로 끊습니다. 받은 요청 본문은 [requests]에 쌓입니다.
final class _LunarApi extends Interceptor {
  bool offline = false;
  final requests = <Map<String, Object?>>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path != '/v1/lunar-date') {
      handler.next(options);
      return;
    }
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: '오프라인'),
        true,
      );
      return;
    }
    // 생성 클라이언트는 본문을 JSON 문자열로 싣습니다.
    final body = jsonDecode(options.data as String) as Map<String, Object?>;
    requests.add(body);
    final date = body['date']! as Map;
    final year = date['year']! as int;
    final month = date['month']! as int;
    final day = date['day']! as int;
    final leap = body['isLeapMonth']! as bool;
    if (month == 3 && day == 30) {
      handler.reject(
        DioException.badResponse(
          statusCode: 422,
          requestOptions: options,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 422,
            data: {
              'type': 'about:blank',
              'title': 'Invalid',
              'status': 422,
              'code': 'date.invalid',
              'traceId': 'test',
            },
            headers: Headers.fromMap({
              Headers.contentTypeHeader: ['application/problem+json'],
            }),
          ),
        ),
        true,
      );
      return;
    }
    final solarMonth = (month + (leap ? 2 : 1)).clamp(1, 12);
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'solarDate': '$year-${_two(solarMonth)}-${_two(day)}',
          'monthHasLeap': year == 2023 && month == 2,
        },
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/json'],
        }),
      ),
      true,
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

Future<ProviderContainer> _openBirth(
  WidgetTester tester, {
  required Locale locale,
  LunarOrSolarDate? date,
  CalendarType calendar = CalendarType.solar,
  _LunarApi? lunarApi,
}) async {
  final container = await pumpApp(tester, scenario: 'new-user', locale: locale);
  if (lunarApi != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, lunarApi);
  }
  if (date != null) {
    await tester.runAsync(
      () => container
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(calendar: calendar, date: date)),
    );
  }
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.onboardBirth)),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder get _confirm => find.byKey(BirthDatePicker.solarConfirmKey);

String? _confirmText(WidgetTester tester) {
  final texts = find.descendant(of: _confirm, matching: find.byType(Text));
  if (texts.evaluate().isEmpty) return null;
  return tester.widget<Text>(texts.first).data;
}

Wheel _monthWheel(WidgetTester tester) =>
    tester.widget<Wheel>(find.byKey(BirthDatePicker.monthWheelKey));

/// 월 휠을 한 칸 내리고(스크린리더 증가 동작) 확인 조회가 끝날 때까지 기다립니다.
Future<void> _nextMonth(WidgetTester tester) async {
  tester.semantics.increase(find.semantics.byLabel(_ko.datePickerMonthLabel));
  await tester.pumpAndSettle();
}

Future<void> _settleCheck(WidgetTester tester) async {
  await tester.pump(lunarBirthCheckDelay);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('양력 1900-01-30이면 범위 안내가 보이고 다음이 비활성입니다', (tester) async {
    covers(
      const Covers(states: ['onboard-birth:out-of-range'], decisions: ['D41']),
    );
    await _openBirth(
      tester,
      locale: const Locale('ko', 'KR'),
      date: LunarOrSolarDate(year: 1900, month: 1, day: 30),
    );
    expect(
      find.bySemanticsIdentifier(SlotIds.onboardBirthErrorRange),
      findsOneWidget,
    );
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
  });

  testWidgets('범위 안 날짜면 오류 줄이 없고 다음이 켜집니다', (tester) async {
    await _openBirth(tester, locale: const Locale('ko', 'KR'));
    expect(
      find.bySemanticsIdentifier(SlotIds.onboardBirthErrorRange),
      findsNothing,
    );
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('한국 출생 기준 안내는 한국 기기에서 보입니다 (D29)', (tester) async {
    await _openBirth(tester, locale: const Locale('ko', 'KR'));
    expect(
      find.bySemanticsIdentifier(SlotIds.onboardBirthBasisNote),
      findsOneWidget,
    );
  });

  testWidgets('한국 밖 기기에서는 출생 기준 안내를 숨깁니다 (D29)', (tester) async {
    await _openBirth(tester, locale: const Locale('en', 'US'));
    expect(
      find.bySemanticsIdentifier(SlotIds.onboardBirthBasisNote),
      findsNothing,
    );
  });

  group('음력(V31 목표 모양)', () {
    testWidgets('음력이면 확인 줄에 양력 날짜, 윤달 체크는 없습니다', (tester) async {
      final api = _LunarApi();
      await _openBirth(
        tester,
        locale: const Locale('ko', 'KR'),
        date: LunarOrSolarDate(year: 1990, month: 4, day: 15),
        calendar: CalendarType.lunar,
        lunarApi: api,
      );
      expect(_confirmText(tester), _ko.datePickerSolarConfirm('1990년 5월 15일'));
      expect(find.byType(CheckRow), findsNothing);
      // 1일·평달로 그 달의 윤달을 묻고, 고른 날로 양력을 묻습니다.
      expect(api.requests.map((r) => (r['date']! as Map)['day']), [1, 15]);
    });

    testWidgets('그 달에 윤달이 있으면 윤N월 칸이 끼워지고, 다른 달로 넘겨도 남습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _openBirth(
        tester,
        locale: const Locale('ko', 'KR'),
        date: LunarOrSolarDate(year: 2023, month: 2, day: 1),
        calendar: CalendarType.lunar,
        lunarApi: _LunarApi(),
      );
      expect(_monthWheel(tester).itemCount, 13);
      expect(_monthWheel(tester).itemLabel(2), _ko.datePickerLeapMonthValue(2));

      // 윤2월로 넘기면 확인 줄은 묻는 동안 skeleton, 멈추면 윤달 양력 날짜입니다.
      await _nextMonth(tester);
      expect(
        find.descendant(of: _confirm, matching: find.byType(SkeletonBlock)),
        findsOneWidget,
      );
      await _settleCheck(tester);
      expect(_confirmText(tester), _ko.datePickerSolarConfirm('2023년 4월 1일'));

      // 3월로 넘겨도 그해 윤2월 칸은 그대로입니다(빠졌다 끼워지지 않음).
      await _nextMonth(tester);
      await _settleCheck(tester);
      expect(_monthWheel(tester).itemCount, 13);
      handle.dispose();
    });

    testWidgets('그 달에 없는 날이면 확인 줄에 그 오류 문구', (tester) async {
      await _openBirth(
        tester,
        locale: const Locale('ko', 'KR'),
        date: LunarOrSolarDate(year: 1990, month: 3, day: 30),
        calendar: CalendarType.lunar,
        lunarApi: _LunarApi(),
      );
      expect(_confirmText(tester), _ko.errorDateInvalid);
      // 확인 결과와 상관없이 다음으로 갈 수 있습니다(저장 때 server가 판단).
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('조회가 연결 오류면 확인 줄에 오프라인 문구', (tester) async {
      await _openBirth(
        tester,
        locale: const Locale('ko', 'KR'),
        date: LunarOrSolarDate(year: 1990, month: 4, day: 15),
        calendar: CalendarType.lunar,
        lunarApi: _LunarApi()..offline = true,
      );
      expect(_confirmText(tester), _ko.errorOffline);
    });

    testWidgets('양력이면 확인 줄을 그리지 않고 묻지도 않습니다', (tester) async {
      final api = _LunarApi();
      await _openBirth(tester, locale: const Locale('ko', 'KR'), lunarApi: api);
      expect(_confirm, findsNothing);
      expect(api.requests, isEmpty);
    });
  });
}
