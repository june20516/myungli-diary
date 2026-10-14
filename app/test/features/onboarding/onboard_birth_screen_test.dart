import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../../support/app_harness.dart';

Future<ProviderContainer> _openBirth(
  WidgetTester tester, {
  required Locale locale,
  LunarOrSolarDate? date,
}) async {
  final container = await pumpApp(tester, scenario: 'new-user', locale: locale);
  if (date != null) {
    await tester.runAsync(
      () => container
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(calendar: CalendarType.solar, date: date)),
    );
  }
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.onboardBirth)),
  );
  await tester.pumpAndSettle();
  return container;
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
}
