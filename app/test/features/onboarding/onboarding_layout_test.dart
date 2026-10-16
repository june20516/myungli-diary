import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';

import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';

Future<void> _open(
  WidgetTester tester,
  ProviderContainer container,
  String screenId,
) async {
  unawaited(container.read(routerProvider).push<void>(pathOf(screenId)));
  await tester.pumpAndSettle();
}

void main() {
  // notify-ask는 허락·건너뛰기 두 버튼이 있어, 둘 다 화면 안에서 스크롤 없이 닿아야 합니다.
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('notify-ask: 글자 $scale배에서 넘치지 않고 두 버튼에 닿습니다', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openNotifyAsk(tester);

      expect(tester.takeException(), isNull);
      final buttons = find.byType(PrimaryButton);
      expect(buttons, findsNWidgets(2));
      for (final button in buttons.evaluate()) {
        final finder = find.byElementPredicate((e) => e == button);
        expect(tester.getBottomLeft(finder).dy, lessThanOrEqualTo(568));
        expect(tester.getTopLeft(finder).dy, greaterThanOrEqualTo(0));
      }
    });
  }

  for (final screenId in [
    ScreenIds.onboardCall,
    ScreenIds.onboardBirth,
    ScreenIds.onboardTime,
    ScreenIds.onboardGender,
  ]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      for (final keyboard in [0.0, 280.0]) {
        testWidgets('$screenId: 글자 $scale배·키보드 $keyboard에서 넘치지 않고 버튼에 닿습니다', (
          tester,
        ) async {
          tester.view
            ..physicalSize = const Size(320, 568)
            ..devicePixelRatio = 1
            ..viewInsets = FakeViewPadding(bottom: keyboard);
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final container = await pumpApp(tester, scenario: 'new-user');
          await _open(tester, container, screenId);

          expect(tester.takeException(), isNull);
          final button = find.byType(PrimaryButton);
          expect(button, findsOneWidget);
          // 버튼이 화면 안에 있고(키보드가 열렸으면 키보드 위), 스크롤 없이 닿습니다.
          final bottom = tester.getBottomLeft(button).dy;
          expect(bottom, lessThanOrEqualTo(568 - keyboard));
          expect(tester.getTopLeft(button).dy, greaterThanOrEqualTo(0));
        });
      }
    }
  }

  // 시진 확인 줄이 보이는 상태에서도 넘치지 않고 버튼에 닿습니다.
  for (final scale in [1.0, 3.0]) {
    for (final keyboard in [0.0, 280.0]) {
      testWidgets('onboard-time 확인 줄 표시: 글자 $scale배·키보드 $keyboard', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1
          ..viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await pumpApp(
          tester,
          scenario: 'new-user',
          locale: const Locale('ko', 'KR'),
        );
        await tester.runAsync(
          () => container
              .read(onboardingDraftProvider.notifier)
              .update(
                (d) => d.copyWith(
                  calendar: CalendarType.solar,
                  date: LunarOrSolarDate(year: 1990, month: 5, day: 17),
                ),
              ),
        );
        await _open(tester, container, ScreenIds.onboardTime);
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey(SlotIds.onboardTimeHourConfirm)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final button = find.byType(PrimaryButton);
        expect(
          tester.getBottomLeft(button).dy,
          lessThanOrEqualTo(568 - keyboard),
        );
        expect(tester.getTopLeft(button).dy, greaterThanOrEqualTo(0));
      });
    }
  }

  // birthplace는 고르면 바로 넘어가는 단계라 아래 버튼이 없습니다(`bottomAction.omitWhen`).
  // 결과가 보여도 넘치지 않고, 마지막 결과 줄까지 스크롤해 키보드 위에서 닿습니다.
  for (final scale in [1.0, 2.0, 3.0]) {
    for (final keyboard in [0.0, 280.0]) {
      testWidgets('birthplace: 글자 $scale배·키보드 $keyboard에서 아래 버튼 없이 넘치지 않고 '
          '마지막 결과 줄을 누를 수 있습니다', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1
          ..viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await pumpApp(tester, scenario: 'overseas');
        await _open(tester, container, ScreenIds.birthplace);
        expect(tester.takeException(), isNull);
        expect(find.byType(PrimaryButton), findsNothing);

        await tester.enterText(find.byType(EditableText), 'new');
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(CitySearch.resultsKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byType(PrimaryButton), findsNothing);
        final lastRow = find.byKey(CitySearch.rowKey('1261481'));
        await tester.ensureVisible(lastRow);
        await tester.pumpAndSettle();
        // 3배 글자·키보드에서는 줄 하나가 남은 높이보다 클 수 있어, 누를 수 있는 높이(48)가
        // 키보드 위에 보이는지 봅니다.
        final top = tester.getTopLeft(lastRow).dy;
        expect(top, greaterThanOrEqualTo(0));
        expect(top + 48, lessThanOrEqualTo(568 - keyboard));
      });
    }
  }

  // 미리보기: 풀이가 보이는 상태와 오류 상태 모두에서 넘치지 않고 아래 버튼 둘에 닿습니다.
  for (final scenario in ['new-user', 'preview-used']) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('preview($scenario): 글자 $scale배에서 넘치지 않고 버튼에 닿습니다', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await pumpApp(
          tester,
          scenario: scenario,
          locale: const Locale('ko', 'KR'),
        );
        await tester.runAsync(
          () => container
              .read(onboardingDraftProvider.notifier)
              .update(
                (d) => d.copyWith(
                  honorific: '별님',
                  calendar: CalendarType.solar,
                  date: LunarOrSolarDate(year: 1990, month: 5, day: 17),
                  time: BirthTime(status: BirthTimeStatusEnum.unknown),
                  gender: BirthGenderEnum.female,
                ),
              ),
        );
        await _open(tester, container, ScreenIds.preview);
        await settlePreview(tester);

        expect(tester.takeException(), isNull);
        for (final slot in [
          SlotIds.previewCtaSave,
          SlotIds.previewCtaRestart,
        ]) {
          final box = tester.getRect(find.byKey(ValueKey(slot)));
          expect(box.bottom, lessThanOrEqualTo(568));
          expect(box.top, greaterThanOrEqualTo(0));
        }
      });
    }
  }
}
