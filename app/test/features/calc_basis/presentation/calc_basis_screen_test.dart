import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_en.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ja.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/prose_page_body.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/calc_basis/application/calc_basis_providers.dart';
import 'package:myungli_diary/features/calc_basis/model/time_basis.dart';
import 'package:myungli_diary/features/calc_basis/presentation/calc_basis_screen.dart';

import '../../../support/app_bar_title.dart';

final _ko = AppLocalizationsKo();

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

/// 본문 문단 슬롯. 화면에 놓이는 순서입니다.
const List<String> _bodySlots = [
  SlotIds.calcBasisConventionBody,
  SlotIds.calcBasisSchoolsBody,
  SlotIds.calcBasisLongitudeBody,
  SlotIds.calcBasisLunarBody,
];

/// [timeBasis]로 경도 기준을, [crash]로 crash 보고를 덮는 override.
List<Override> _overrides(
  Future<TimeBasis?> Function() timeBasis,
  FakeCrashReporter crash,
) => [
  calcBasisTimeBasisProvider.overrideWith((ref) {
    // 실제 provider처럼 받은 값은 화면을 떠나도 둡니다.
    ref.keepAlive();
    return timeBasis();
  }),
  crashReporterProvider.overrideWithValue(crash),
];

/// ko 테마·로케일의 앱 껍데기.
Widget _material(Widget home) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: home,
);

/// [timeBasis]로 경도 기준을 덮은 앱. [home]이 없으면 계산 기준 화면 하나만 띄웁니다.
Widget _app(
  Future<TimeBasis?> Function() timeBasis, {
  FakeCrashReporter? crash,
  Widget home = const CalcBasisScreen(),
}) => ProviderScope(
  overrides: _overrides(timeBasis, crash ?? FakeCrashReporter()),
  child: _material(home),
);

/// seep으로 나타나는 중인 경도 문단.
final Finder _seepingLongitude = find.ancestor(
  of: find.byKey(const ValueKey(SlotIds.calcBasisLongitudeBody)),
  matching: find.byType(SeepPresence),
);

/// 경도 문단의 글자. 없으면 null입니다.
String? _longitudeText(WidgetTester tester) {
  final paragraph = find.byKey(const ValueKey(SlotIds.calcBasisLongitudeBody));
  if (paragraph.evaluate().isEmpty) return null;
  final rich = tester.widget<RichText>(
    find.descendant(of: paragraph, matching: find.byType(RichText)).first,
  );
  return rich.text.toPlainText();
}

void main() {
  testWidgets(
    '제목은 계산 기준, 본문은 convention → schools → longitude → lunar 순서 (A30)',
    (tester) async {
      await tester.pumpWidget(
        _app(
          () async => const TimeBasis(longitude: 127.5, correctionMinutes: -30),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey(ScreenIds.calcBasis)), findsOneWidget);
      expect(_id(ScreenIds.calcBasis), findsOneWidget);
      expect(find.text(_ko.calcBasisBarTitle), findsOneWidget);
      final tops = [
        for (final slot in _bodySlots) tester.getTopLeft(_id(slot)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(
        find.text(_ko.calcBasisConventionBody, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text(_ko.calcBasisSchoolsBody, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text(_ko.calcBasisLunarBody, findRichText: true),
        findsOneWidget,
      );
    },
  );

  group('경도 문단 (A28)', () {
    final cases = <String, (TimeBasis, String)>{
      '한국 127.5° −30분은 빼기': (
        const TimeBasis(longitude: 127.5, correctionMinutes: -30),
        _ko.calcBasisLongitudeBodySubtract(
          _ko.calcBasisLongitudeBodyEast('127.5'),
          30,
        ),
      ),
      '일본 135° 0분은 보정 없음': (
        const TimeBasis(longitude: 135, correctionMinutes: 0),
        _ko.calcBasisLongitudeBodyNone(_ko.calcBasisLongitudeBodyEast('135')),
      ),
      '양수 보정은 더하기': (
        const TimeBasis(longitude: 139.69, correctionMinutes: 19),
        _ko.calcBasisLongitudeBodyAdd(
          _ko.calcBasisLongitudeBodyEast('139.69'),
          19,
        ),
      ),
      '음수 경도는 서경(절댓값)': (
        const TimeBasis(longitude: -74.01, correctionMinutes: 4),
        _ko.calcBasisLongitudeBodyAdd(
          _ko.calcBasisLongitudeBodyWest('74.01'),
          4,
        ),
      ),
    };
    for (final MapEntry(key: name, value: (basis, expected)) in cases.entries) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(_app(() async => basis));
        await tester.pumpAndSettle();

        expect(_longitudeText(tester), expected);
        expect(_id(SlotIds.calcBasisLongitudeBody), findsOneWidget);
      });
    }

    testWidgets('기준을 모르면(null) 경도 문단을 그리지 않고 자리도 남기지 않습니다 (A29)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(() async => null));
      await tester.pumpAndSettle();

      expect(_id(SlotIds.calcBasisLongitudeBody), findsNothing);
      expect(find.byType(SkeletonBlock), findsNothing);
      for (final slot in _bodySlots) {
        if (slot == SlotIds.calcBasisLongitudeBody) continue;
        expect(_id(slot), findsOneWidget, reason: slot);
      }
      // 자리를 남기지 않으므로 schools와 lunar 사이 간격이 다른 문단 사이 간격과 같습니다.
      final schools = tester.getRect(_id(SlotIds.calcBasisSchoolsBody));
      final lunar = tester.getRect(_id(SlotIds.calcBasisLunarBody));
      final convention = tester.getRect(_id(SlotIds.calcBasisConventionBody));
      expect(lunar.top - schools.bottom, schools.top - convention.bottom);
    });

    testWidgets('서머타임 기간 출생이면 Dst 문구로 경도 문단을 그립니다 (#214)', (tester) async {
      await tester.pumpWidget(
        _app(
          () async => const TimeBasis(
            longitude: 127.5,
            correctionMinutes: -30,
            daylightSavingMinutes: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = _longitudeText(tester)!;
      // 원고(#214 표)와 계산이 함께 맞음을 문장 그대로 고정합니다.
      expect(text, contains('서머타임 60분을 먼저 빼고, 동경 127.5° 기준으로 30분을 더 빼서'));
      expect(
        text,
        _ko.calcBasisLongitudeBodyDstSubtract(
          _ko.calcBasisLongitudeBodyEast('127.5'),
          30,
          60,
        ),
      );
      expect(_id(SlotIds.calcBasisLongitudeBody), findsOneWidget);
    });

    testWidgets('1955년 서머타임 출생은 DstNone 문구입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          () async => const TimeBasis(
            longitude: 127.5,
            correctionMinutes: 0,
            daylightSavingMinutes: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _longitudeText(tester),
        _ko.calcBasisLongitudeBodyDstNone(
          _ko.calcBasisLongitudeBodyEast('127.5'),
          60,
        ),
      );
      expect(_longitudeText(tester), contains('서머타임 60분만 빼고'));
    });

    test('en·ja도 서머타임 분기마다 ARB 값에 인자를 채운 문장입니다', () {
      const basis = TimeBasis(
        longitude: 127.5,
        correctionMinutes: -30,
        daylightSavingMinutes: 60,
      );
      final en = AppLocalizationsEn();
      final ja = AppLocalizationsJa();

      expect(
        calcBasisLongitudeText(en, basis),
        en.calcBasisLongitudeBodyDstSubtract(
          en.calcBasisLongitudeBodyEast('127.5'),
          30,
          60,
        ),
      );
      expect(
        calcBasisLongitudeText(ja, basis),
        ja.calcBasisLongitudeBodyDstSubtract(
          ja.calcBasisLongitudeBodyEast('127.5'),
          30,
          60,
        ),
      );
      expect(calcBasisLongitudeText(en, basis), contains('60-minute'));
    });

    testWidgets('서머타임과 양수 보정은 DstAdd 문구입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          () async => const TimeBasis(
            longitude: -74.01,
            correctionMinutes: 4,
            daylightSavingMinutes: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _longitudeText(tester),
        _ko.calcBasisLongitudeBodyDstAdd(
          _ko.calcBasisLongitudeBodyWest('74.01'),
          4,
          60,
        ),
      );
    });

    testWidgets('불러오는 중에는 그 자리에 skeleton 한 문단, 다른 문단은 바로 보입니다', (tester) async {
      final pending = Completer<TimeBasis?>();
      await tester.pumpWidget(_app(() => pending.future));
      await tester.pump();

      for (final slot in _bodySlots) {
        if (slot == SlotIds.calcBasisLongitudeBody) continue;
        expect(_id(slot), findsOneWidget, reason: slot);
      }
      expect(_id(SlotIds.calcBasisLongitudeBody), findsNothing);
      // skeleton이 나타나기 전(높이 0)에는 간격도 없어 문단 간격은 한 번입니다.
      expect(
        tester.getRect(_id(SlotIds.calcBasisLunarBody)).top -
            tester.getRect(_id(SlotIds.calcBasisSchoolsBody)).bottom,
        ProsePageBody.paragraphGap,
      );

      // skeleton은 300ms 뒤에야 보입니다.
      await tester.pump(SkeletonBlock.defaultDelay);
      final skeleton = find.byType(SkeletonBlock);
      expect(skeleton, findsOneWidget);
      final schools = tester.getRect(_id(SlotIds.calcBasisSchoolsBody));
      final lunar = tester.getRect(_id(SlotIds.calcBasisLunarBody));
      final bone = tester.getRect(skeleton);
      expect(bone.top, greaterThan(schools.bottom));
      expect(bone.bottom, lessThan(lunar.top));

      pending.complete(
        const TimeBasis(longitude: 127.5, correctionMinutes: -30),
      );
      await tester.pump();
      // 불러오는 중을 보인 뒤라 값은 appear.seep으로 나타납니다.
      expect(_seepingLongitude, findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonBlock), findsNothing);
      expect(_id(SlotIds.calcBasisLongitudeBody), findsOneWidget);
    });

    testWidgets('이미 받아 둔 값으로 다시 열면 seep 없이 바로 보입니다', (tester) async {
      final container = ProviderContainer(
        overrides: _overrides(
          () async => const TimeBasis(longitude: 127.5, correctionMinutes: -30),
          FakeCrashReporter(),
        ),
      );
      addTearDown(container.dispose);
      await container.read(calcBasisTimeBasisProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _material(const CalcBasisScreen()),
        ),
      );

      expect(_id(SlotIds.calcBasisLongitudeBody), findsOneWidget);
      expect(_seepingLongitude, findsNothing);
      expect(find.byType(SkeletonBlock), findsNothing);
    });

    testWidgets('기준 계산이 실패하면 경도 문단을 그리지 않고 crash 요약을 남깁니다', (tester) async {
      final crash = FakeCrashReporter();
      await tester.pumpWidget(
        _app(
          () async => throw ArgumentError.value('Nowhere/City', 'timezone'),
          crash: crash,
        ),
      );
      await tester.pumpAndSettle();

      expect(_id(SlotIds.calcBasisLongitudeBody), findsNothing);
      expect(find.byType(SkeletonBlock), findsNothing);
      expect(_id(SlotIds.calcBasisLunarBody), findsOneWidget);
      expect(crash.errors.map((e) => e.errorType), ['ArgumentError']);
    });

    testWidgets('이미 분류된 AppError면 문단만 빼고 crash 요약은 남기지 않습니다', (tester) async {
      final crash = FakeCrashReporter();
      await tester.pumpWidget(
        _app(() async => throw const OfflineError(), crash: crash),
      );
      await tester.pumpAndSettle();

      expect(_id(SlotIds.calcBasisLongitudeBody), findsNothing);
      expect(find.byType(SkeletonBlock), findsNothing);
      expect(crash.errors, isEmpty);
    });
  });

  testWidgets('뒤로 버튼은 앞 화면으로 돌아갑니다', (tester) async {
    await tester.pumpWidget(
      _app(
        () async => null,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const CalcBasisScreen()),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.calcBasis)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-bar.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.calcBasis)), findsNothing);
  });

  testWidgets('스택 바닥(딥링크·복원)에서는 뒤로 버튼을 그리지 않습니다', (tester) async {
    await tester.pumpWidget(_app(() async => null));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-bar.back')), findsNothing);
    expect(find.text(_ko.calcBasisBarTitle), findsOneWidget);
    expectAppBarTitle(SlotIds.calcBasisBarTitle, _ko.calcBasisBarTitle);
  });

  testWidgets('큰 글자(2.0)·작은 화면에서도 넘치지 않고 본문이 스크롤됩니다', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _app(
        () async => const TimeBasis(longitude: 127.5, correctionMinutes: -30),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final lunar = find.byKey(const ValueKey(SlotIds.calcBasisLunarBody));
    await tester.scrollUntilVisible(lunar, 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(lunar).bottom, lessThanOrEqualTo(568));
  });
}
