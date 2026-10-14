import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_en.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_finish.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';

const Locale _usa = Locale('en', 'US');

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
}

/// 파일 DB·fixture의 실제 I/O가 끝나도록 시계를 풀어 줍니다.
Future<void> _settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// 환영 → 호칭 → 생일 → 시간 → 성별을 넘겨 birthplace까지 갑니다.
Future<ProviderContainer> _openBirthplace(
  WidgetTester tester, {
  String scenario = 'overseas',
  List<Override> overrides = const [],
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    locale: _usa,
    overrides: overrides,
  );
  final start = find.byKey(const ValueKey(SlotIds.welcomeCtaStart));
  if (start.evaluate().isNotEmpty) {
    await tester.tap(start);
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(EditableText), 'Luna');
  await tester.pump();
  await _tapNext(tester); // 호칭
  await _tapNext(tester); // 생일
  await _tapNext(tester); // 시간
  await tester.tap(find.text('Male'));
  await tester.pumpAndSettle();
  await _tapNext(tester); // 성별
  expect(find.byKey(const ValueKey(ScreenIds.birthplace)), findsOneWidget);
  return container;
}

/// 검색칸에 [text]를 치고 debounce(300ms)가 지나 요청이 나가도록 시계를 돌립니다.
Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.pump(const Duration(milliseconds: 301));
}

/// 결과 줄(첫 도시)을 누르는 대상.
final Finder _newYork = find.text('New York City');

void main() {
  testWidgets('입력이 멈추고 300ms 뒤에 한 번 요청하고, 받는 동안 skeleton입니다', (tester) async {
    covers(const Covers(states: ['birthplace:loading'], decisions: ['D29']));
    // 응답이 1초 걸리는 시나리오라 받는 동안의 화면을 볼 수 있습니다.
    final container = await _openBirthplace(tester, scenario: 'cities-slow');
    final fake = _fake(container);

    await tester.enterText(find.byType(EditableText), 'new');
    await tester.pump(const Duration(milliseconds: 299));
    expect(fake.callCountOf('listCities'), 0);

    await tester.pump(const Duration(milliseconds: 2));
    // 응답을 기다리는 동안 skeleton 줄 3개가 나옵니다.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SkeletonBone), findsNWidgets(3));
    expect(find.byKey(CitySearch.resultsKey), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await _settleIo(tester);
    expect(find.byType(SkeletonBone), findsNothing);
    expect(find.byKey(CitySearch.rowKey('5128581')), findsOneWidget);
    expect(fake.callCountOf('listCities'), 1);
  });

  testWidgets('연속 입력은 마지막 한 번만 요청하고, 빈 입력은 요청하지 않습니다', (tester) async {
    final container = await _openBirthplace(tester);
    final fake = _fake(container);

    await tester.enterText(find.byType(EditableText), 'n');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(EditableText), 'ne');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(EditableText), 'new');
    await tester.pump(const Duration(milliseconds: 301));
    await _settleIo(tester);
    expect(fake.callCountOf('listCities'), 1);
    expect(find.byKey(CitySearch.resultsKey), findsOneWidget);

    // 지우면 결과도 사라지고 요청도 없습니다.
    await tester.enterText(find.byType(EditableText), '  ');
    await tester.pump(const Duration(milliseconds: 301));
    await _settleIo(tester);
    expect(fake.callCountOf('listCities'), 1);
    expect(find.byKey(CitySearch.resultsKey), findsNothing);
  });

  testWidgets('도시를 누르면 초안에 담고 preview로 갑니다', (tester) async {
    covers(const Covers(exits: ['birthplace>preview'], decisions: ['D29']));
    final container = await _openBirthplace(tester);
    await _search(tester, 'new');
    await _settleIo(tester);

    await tester.tap(_newYork);
    await _settleIo(tester);

    final city = container.read(onboardingDraftProvider).value!.city;
    expect(city?.timezone, 'America/New_York');
    expect(city?.id, '5128581');
    expect(find.byKey(const ValueKey(ScreenIds.preview)), findsOneWidget);
  });

  testWidgets('결과가 없으면 안내 문장이 나옵니다', (tester) async {
    covers(const Covers(states: ['birthplace:empty']));
    await _openBirthplace(tester);
    await _search(tester, 'new');
    await _settleIo(tester);
    // fixture의 두 번째 응답이 빈 목록입니다.
    await _search(tester, 'zzzz');
    await _settleIo(tester);

    expect(find.byKey(CitySearch.resultsKey), findsNothing);
    expect(find.text('No matching city. Try another name.'), findsOneWidget);
  });

  testWidgets('검색이 실패하면 오류 상태이고 다시 시도로 같은 질의를 다시 보냅니다', (tester) async {
    covers(const Covers(states: ['birthplace:error']));
    final container = await _openBirthplace(tester, scenario: 'cities-error');
    final fake = _fake(container);
    await _search(tester, 'new');
    await _settleIo(tester);

    final retry = find.widgetWithText(PrimaryButton, 'Try again');
    expect(retry, findsOneWidget);
    expect(fake.callCountOf('listCities'), 1);

    await tester.tap(retry);
    await _settleIo(tester);
    expect(fake.callCountOf('listCities'), 2);
    expect(retry, findsOneWidget);
  });

  testWidgets('이전 질의의 늦은 응답은 버립니다', (tester) async {
    // 응답마다 1초가 걸리는 시나리오: 첫 질의의 응답이 둘째 질의를 보낸 뒤에 도착합니다.
    final container = await _openBirthplace(tester, scenario: 'cities-slow');
    final fake = _fake(container);
    await _search(tester, 'new');
    await tester.pump(const Duration(milliseconds: 300));
    await _search(tester, 'newa');

    // 첫 응답(도시 3개)이 도착할 시각을 지났습니다.
    await tester.pump(const Duration(milliseconds: 800));
    await _settleIo(tester);
    expect(fake.callCountOf('listCities'), 2);
    expect(find.byKey(CitySearch.resultsKey), findsNothing);
    expect(_newYork, findsNothing);

    // 둘째 응답(빈 목록)이 보입니다.
    await tester.pump(const Duration(seconds: 1));
    await _settleIo(tester);
    expect(find.text('No matching city. Try another name.'), findsOneWidget);
  });

  testWidgets('세션이 있으면 도시를 고른 뒤 마무리 동작을 한 번 부릅니다', (tester) async {
    final gate = Completer<void>();
    var finished = 0;
    final container = await _openBirthplace(
      tester,
      scenario: 'profile-required',
      overrides: [
        onboardingFinishProvider.overrideWithValue(() {
          finished++;
          return gate.future;
        }),
      ],
    );
    await _search(tester, 'new');
    await _settleIo(tester);

    await tester.tap(_newYork);
    await tester.pump();
    await tester.tap(_newYork, warnIfMissed: false);
    await tester.pump();

    expect(finished, 1);
    expect(find.byKey(const ValueKey(ScreenIds.preview)), findsNothing);
    expect(container.read(onboardingDraftProvider).value!.city?.id, '5128581');
    gate.complete();
    await tester.pumpAndSettle();
  });

  for (final parent in [ScreenIds.profileEdit, ScreenIds.settings]) {
    testWidgets('수정 모드: $parent에서 열면 고른 City를 돌려줍니다', (tester) async {
      covers(
        const Covers(exits: ['birthplace>profile-edit', 'birthplace>settings']),
      );
      final container = await pumpApp(
        tester,
        scenario: 'member-overseas',
        locale: _usa,
      );
      final router = container.read(routerProvider);
      unawaited(router.push<void>(pathOf(parent)));
      await tester.pumpAndSettle();

      City? result;
      unawaited(
        router
            .push<City>('${pathOf(ScreenIds.birthplace)}?mode=edit')
            .then((value) => result = value),
      );
      await tester.pumpAndSettle();
      // 수정 모드는 진행 막대 없이 저장 버튼 자리에 서고 초안에는 쓰지 않습니다.
      expect(find.byKey(InputStep.progressKey), findsNothing);
      await _search(tester, 'new');
      await _settleIo(tester);
      await tester.tap(_newYork);
      await tester.pumpAndSettle();

      expect(result?.id, '5128581');
      expect(result?.timezone, 'America/New_York');
      expect(find.byKey(ValueKey(parent)), findsOneWidget);
      expect(container.read(onboardingDraftProvider).value?.city, isNull);
    });
  }

  testWidgets('슬롯 identifier: 검색칸(search.hint)과 빈 결과 문장(empty.body)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openBirthplace(tester);
    expect(
      find.bySemanticsIdentifier(SlotIds.birthplaceSearchHint),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(SlotIds.birthplaceEmptyBody),
      findsNothing,
    );

    await _search(tester, 'new');
    await _settleIo(tester);
    await _search(tester, 'zzzz');
    await _settleIo(tester);
    expect(
      find.bySemanticsIdentifier(SlotIds.birthplaceEmptyBody),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('마무리 동작이 실패하면 toast로 안내하고 다시 고를 수 있습니다', (tester) async {
    var calls = 0;
    await _openBirthplace(
      tester,
      scenario: 'profile-required',
      overrides: [
        onboardingFinishProvider.overrideWithValue(() async {
          calls++;
          throw StateError('저장 실패');
        }),
      ],
    );
    await _search(tester, 'new');
    await _settleIo(tester);

    await tester.tap(_newYork);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        errorMessage(AppLocalizationsEn(), UnexpectedError(StateError('x'))),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(_newYork);
    await tester.pump();
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 10));
  });
}
